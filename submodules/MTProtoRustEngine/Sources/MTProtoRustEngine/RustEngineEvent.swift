import Foundation
import MTProtoEngineFFI
import MTProtoRustEngineMapping

enum RustEngineEventKind: UInt32 {
    case completed = 1
    case failed = 2
    case acknowledged = 3
    case progress = 4
    case floodWaitReported = 5
    case authorizationRequired = 6
    case softAuthReset = 7
    case authTokenRequired = 8
    case temporaryKeyRejected = 9
    case initHashStored = 10
    case initHashCleared = 11
    case verificationRequired = 12
    case updatesReset = 13
    case update = 14
    case timeDifferenceUpdated = 15
    case saltsUpdated = 16
    case pong = 17
    case connectionState = 18
    case authKeyRequired = 19
    case authKeyInvalid = 20
    case authKeyCreated = 21
    case authKeyCreationFailed = 22
    case transportFlood = 23
    case networkUsage = 24
    case addressResult = 25
    case closed = 26
    case retryDecisionRequired = 27
    case connectionDropped = 29
    case temporaryKeyBound = 30
    case temporaryKeyBindFailed = 31
    case permanentKeyInvalid = 32
    case temporaryKeyInUse = 33
    case temporaryKeyDropped = 34
    case routeMemoryChanged = 35
}

struct RustEngineEvent {
    let rawKind: UInt32
    let requestId: UInt64
    let code: Int32
    let flags: UInt32
    let text: String
    let text2: String
    let payload: Data?
    let value1: Double
    let value2: Double
    let integer1: Int64
    let integer2: Int64
    let salts: [RustEngineSalt]

    var kind: RustEngineEventKind? {
        return RustEngineEventKind(rawValue: self.rawKind)
    }

    init(_ event: UnsafePointer<MTEvent>) {
        let raw = event.pointee
        self.rawKind = raw.kind.rawValue
        self.requestId = raw.request_id
        self.code = raw.code
        self.flags = raw.flags
        self.text = rustEngineString(raw.text)
        self.text2 = rustEngineString(raw.text2)
        self.payload = rustEngineTakePayload(raw.payload)
        self.value1 = raw.value1
        self.value2 = raw.value2
        self.integer1 = raw.integer1
        self.integer2 = raw.integer2
        var salts: [RustEngineSalt] = []
        if let pointer = raw.salts, raw.salt_count > 0 {
            salts.reserveCapacity(raw.salt_count)
            for index in 0 ..< raw.salt_count {
                let entry = pointer[index]
                salts.append(RustEngineSalt(salt: entry.salt, validSince: entry.valid_since, validUntil: entry.valid_until))
            }
        }
        self.salts = salts
    }
}
