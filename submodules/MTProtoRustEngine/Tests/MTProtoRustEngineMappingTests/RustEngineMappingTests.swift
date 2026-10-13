import XCTest
@testable import MTProtoRustEngineMapping

final class RustEngineMappingTests: XCTestCase {
    func testRequestFlagsAlwaysDelegateRetryDecisions() {
        let flags = rustEngineRequestFlags(wantsQuickAck: false, wantsProgress: false, needsTimeoutTimer: false, withoutUpdates: false)
        XCTAssertEqual(flags, RustEngineRequestFlags.delegateRetryDecisions)
        XCTAssertEqual(flags & RustEngineRequestFlags.automaticFloodWait, 0)
        XCTAssertEqual(flags & RustEngineRequestFlags.retryServerErrors, 0)
        XCTAssertEqual(flags & RustEngineRequestFlags.reportFloodWait, 0)
    }

    func testRequestFlagsFollowRequestFields() {
        let all = rustEngineRequestFlags(wantsQuickAck: true, wantsProgress: true, needsTimeoutTimer: true, withoutUpdates: true)
        XCTAssertEqual(all, RustEngineRequestFlags.delegateRetryDecisions | RustEngineRequestFlags.quickAck | RustEngineRequestFlags.progress | RustEngineRequestFlags.timeoutTimer | RustEngineRequestFlags.withoutUpdates)
        let ackOnly = rustEngineRequestFlags(wantsQuickAck: true, wantsProgress: false, needsTimeoutTimer: false, withoutUpdates: false)
        XCTAssertEqual(ackOnly, RustEngineRequestFlags.delegateRetryDecisions | RustEngineRequestFlags.quickAck)
    }

    func testHeaderBitValues() {
        XCTAssertEqual(RustEngineRequestFlags.automaticFloodWait, 1)
        XCTAssertEqual(RustEngineRequestFlags.reportFloodWait, 2)
        XCTAssertEqual(RustEngineRequestFlags.retryServerErrors, 4)
        XCTAssertEqual(RustEngineRequestFlags.quickAck, 8)
        XCTAssertEqual(RustEngineRequestFlags.progress, 16)
        XCTAssertEqual(RustEngineRequestFlags.timeoutTimer, 32)
        XCTAssertEqual(RustEngineRequestFlags.withoutUpdates, 64)
        XCTAssertEqual(RustEngineRequestFlags.delegateRetryDecisions, 128)
    }

    func testNoopFlagsHaveNoErrorGate() {
        XCTAssertEqual(rustEngineNoopFlags(withoutUpdates: false), RustEngineRequestFlags.automaticFloodWait)
        XCTAssertEqual(rustEngineNoopFlags(withoutUpdates: true), RustEngineRequestFlags.automaticFloodWait | RustEngineRequestFlags.withoutUpdates)
    }

    func testExpectedResponseSize() {
        XCTAssertEqual(rustEngineExpectedResponseSize(0), 0)
        XCTAssertEqual(rustEngineExpectedResponseSize(-5), 0)
        XCTAssertEqual(rustEngineExpectedResponseSize(512 * 1024), 512 * 1024)
        XCTAssertEqual(rustEngineExpectedResponseSize(Int32.max), UInt32(Int32.max))
    }

    func testSaltConversionRoundTrip() {
        let first: Int64 = 1_760_000_000 << 32
        let last: Int64 = (1_760_000_000 + 1800) << 32
        let salt = rustEngineSalt(salt: 0x1234_5678_9abc_def0, firstValidMessageId: first, lastValidMessageId: last)
        XCTAssertEqual(salt.salt, 0x1234_5678_9abc_def0)
        XCTAssertEqual(salt.validSince, 1_760_000_000, accuracy: 0.000001)
        XCTAssertEqual(salt.validUntil, 1_760_001_800, accuracy: 0.000001)
        let range = rustEngineMessageIdRange(salt)
        XCTAssertEqual(range?.first, first)
        XCTAssertEqual(range?.last, last)
    }

    func testFractionalSaltWindow() {
        let salt = RustEngineSalt(salt: 7, validSince: 1_760_000_000.5, validUntil: 1_760_000_600.25)
        let range = rustEngineMessageIdRange(salt)
        XCTAssertEqual(range?.first, (1_760_000_000 << 32) + (1 << 31))
        XCTAssertEqual(range?.last, (1_760_000_600 << 32) + (1 << 30))
    }

    func testPlaceholderSaltIsDropped() {
        XCTAssertNil(rustEngineMessageIdRange(RustEngineSalt(salt: 0, validSince: -.infinity, validUntil: -.infinity)))
        XCTAssertNil(rustEngineMessageIdRange(RustEngineSalt(salt: 0, validSince: 0, validUntil: .infinity)))
        XCTAssertNil(rustEngineMessageIdRange(RustEngineSalt(salt: 0, validSince: .nan, validUntil: 10)))
        XCTAssertNil(rustEngineMessageIdRange(RustEngineSalt(salt: 0, validSince: 10, validUntil: 10)))
        XCTAssertNil(rustEngineMessageId(seconds: 1e30))
    }

    func testDependencyScansNewestFirst() {
        let candidates = [(id: 1, peer: 10), (id: 2, peer: 20), (id: 3, peer: 10), (id: 4, peer: 30)]
        let index = rustEngineDependencyIndex(candidates: candidates, accepts: { $0.peer == 10 })
        XCTAssertEqual(index.map { candidates[$0].id }, 3)
        XCTAssertNil(rustEngineDependencyIndex(candidates: candidates, accepts: { $0.peer == 40 }))
        XCTAssertNil(rustEngineDependencyIndex(candidates: [Int](), accepts: { _ in true }))
    }

    func testErrorStateIsCumulative() {
        var state = RustEngineErrorState()
        let flood = state.applyRetryDecision(floodWaitSeconds: 3, floodWaitErrorText: "FLOOD_WAIT_3", serverErrors: 0)
        XCTAssertEqual(flood, RustEngineErrorState.Context(floodWaitSeconds: 3, floodWaitErrorText: "FLOOD_WAIT_3", internalServerErrorCount: 0))
        let server = state.applyRetryDecision(floodWaitSeconds: 3, floodWaitErrorText: "FLOOD_WAIT_3", serverErrors: 1)
        XCTAssertEqual(server, RustEngineErrorState.Context(floodWaitSeconds: 3, floodWaitErrorText: "FLOOD_WAIT_3", internalServerErrorCount: 1))
        let parse = state.applyParseFailure()
        XCTAssertEqual(parse.internalServerErrorCount, 2)
        XCTAssertEqual(parse.floodWaitSeconds, 3)
        state.didResubmit()
        let afterResubmit = state.applyRetryDecision(floodWaitSeconds: 0, floodWaitErrorText: nil, serverErrors: 1)
        XCTAssertEqual(afterResubmit, RustEngineErrorState.Context(floodWaitSeconds: 3, floodWaitErrorText: "FLOOD_WAIT_3", internalServerErrorCount: 3))
    }

    func testErrorStateZeroFloodWaitKeepsText() {
        var state = RustEngineErrorState()
        let context = state.applyRetryDecision(floodWaitSeconds: 0, floodWaitErrorText: "FLOOD_WAIT_0", serverErrors: 0)
        XCTAssertEqual(context.floodWaitSeconds, 0)
        XCTAssertEqual(context.floodWaitErrorText, "FLOOD_WAIT_0")
    }

    func testParseFailurePolicyCapsAtThreeAttempts() {
        XCTAssertTrue(RustEngineParseFailurePolicy.shouldResubmit(parseFailures: 1, gateAllowsRetry: true))
        XCTAssertTrue(RustEngineParseFailurePolicy.shouldResubmit(parseFailures: 2, gateAllowsRetry: true))
        XCTAssertFalse(RustEngineParseFailurePolicy.shouldResubmit(parseFailures: 3, gateAllowsRetry: true))
        XCTAssertFalse(RustEngineParseFailurePolicy.shouldResubmit(parseFailures: 1, gateAllowsRetry: false))
        XCTAssertEqual(RustEngineParseFailurePolicy.errorCode, 500)
        XCTAssertEqual(RustEngineParseFailurePolicy.errorText, "TL_PARSING_ERROR")
        XCTAssertEqual(RustEngineParseFailurePolicy.retryDelay, 2.0)
    }

    func testMissingKeyActionMatchesMtProtoKit() {
        XCTAssertEqual(rustEngineMissingKeyAction(isCdn: true, requiresForeignAuthToken: false, selectorIsEphemeral: false), .dropAndRequire(isCdn: true))
        XCTAssertEqual(rustEngineMissingKeyAction(isCdn: false, requiresForeignAuthToken: true, selectorIsEphemeral: true), .removeTokenDropAndRequire)
        XCTAssertEqual(rustEngineMissingKeyAction(isCdn: false, requiresForeignAuthToken: true, selectorIsEphemeral: false), .removeTokenDropAndRequire)
        XCTAssertEqual(rustEngineMissingKeyAction(isCdn: false, requiresForeignAuthToken: false, selectorIsEphemeral: true), .dropAndRequire(isCdn: false))
        XCTAssertEqual(rustEngineMissingKeyAction(isCdn: false, requiresForeignAuthToken: false, selectorIsEphemeral: false), .checkIfLoggedOut)
    }

    func testWorkerAuthorizationErrors() {
        XCTAssertTrue(rustEngineWorkerShouldTransferAuthToken(code: 401, text: "AUTH_KEY_UNREGISTERED"))
        XCTAssertTrue(rustEngineWorkerShouldTransferAuthToken(code: 401, text: "SESSION_REVOKED"))
        XCTAssertTrue(rustEngineWorkerShouldTransferAuthToken(code: 401, text: "USER_DEACTIVATED"))
        XCTAssertFalse(rustEngineWorkerShouldTransferAuthToken(code: 401, text: "SESSION_PASSWORD_NEEDED"))
        XCTAssertFalse(rustEngineWorkerShouldTransferAuthToken(code: 400, text: "AUTH_KEY_UNREGISTERED"))
        XCTAssertFalse(rustEngineWorkerShouldTransferAuthToken(code: 406, text: "AUTH_KEY_DUPLICATED"))
    }

    func testSessionRoles() {
        XCTAssertEqual(rustEngineSessionRole(isMain: true, isCdn: false, datacenterId: 2, masterDatacenterId: 2), .main)
        XCTAssertEqual(rustEngineSessionRole(isMain: false, isCdn: false, datacenterId: 2, masterDatacenterId: 2), .worker)
        XCTAssertEqual(rustEngineSessionRole(isMain: false, isCdn: false, datacenterId: 4, masterDatacenterId: 2), .workerRequiringAuthToken)
        XCTAssertEqual(rustEngineSessionRole(isMain: false, isCdn: true, datacenterId: 203, masterDatacenterId: 2), .cdn)
        XCTAssertEqual(RustEngineSessionRole.main.rawValue, 0)
        XCTAssertEqual(RustEngineSessionRole.worker.rawValue, 1)
        XCTAssertEqual(RustEngineSessionRole.workerRequiringAuthToken.rawValue, 2)
        XCTAssertEqual(RustEngineSessionRole.cdn.rawValue, 3)
        XCTAssertFalse(rustEngineRequiresForeignAuthToken(isMain: true, isCdn: false, datacenterId: 4, masterDatacenterId: 2))
        XCTAssertFalse(rustEngineRequiresForeignAuthToken(isMain: false, isCdn: true, datacenterId: 4, masterDatacenterId: 2))
    }

    func testOnlyNonCdnSessionsShareTheirTimeDifference() {
        XCTAssertTrue(rustEngineSharesTimeDifference(isCdn: false))
        XCTAssertFalse(rustEngineSharesTimeDifference(isCdn: true))
    }

    func testObfuscationDatacenterId() {
        XCTAssertEqual(rustEngineObfuscationDatacenterId(datacenterId: 2, isTestingEnvironment: false, preferForMedia: false), 2)
        XCTAssertEqual(rustEngineObfuscationDatacenterId(datacenterId: 2, isTestingEnvironment: false, preferForMedia: true), -2)
        XCTAssertEqual(rustEngineObfuscationDatacenterId(datacenterId: 2, isTestingEnvironment: true, preferForMedia: false), 10002)
        XCTAssertEqual(rustEngineObfuscationDatacenterId(datacenterId: 2, isTestingEnvironment: true, preferForMedia: true), -10002)
        XCTAssertEqual(rustEngineObfuscationDatacenterId(datacenterId: 203, isTestingEnvironment: false, preferForMedia: false), 203)
    }

    func testAddressOrder() {
        XCTAssertEqual(rustEngineAddressOrder(isIpv6: [false, true, false], preferredIndex: 2, allowIpv6: false), [2, 0])
        XCTAssertEqual(rustEngineAddressOrder(isIpv6: [false, true, false], preferredIndex: 1, allowIpv6: true), [1, 0, 2])
        XCTAssertEqual(rustEngineAddressOrder(isIpv6: [false, true, false], preferredIndex: nil, allowIpv6: true), [0, 2, 1])
        XCTAssertEqual(rustEngineAddressOrder(isIpv6: [true, true], preferredIndex: nil, allowIpv6: false), [0, 1])
        XCTAssertEqual(rustEngineAddressOrder(isIpv6: [false], preferredIndex: 5, allowIpv6: false), [0])
        XCTAssertEqual(rustEngineAddressOrder(isIpv6: [], preferredIndex: nil, allowIpv6: true), [])
    }

    func testConnectionFlags() {
        let none = RustEngineConnectionFlags(rawValue: 0)
        XCTAssertFalse(none.isNetworkAvailable || none.isConnected || none.isUpdatingConnectionContext || none.isPerformingServiceTasks || none.proxyHasConnectionIssues || none.isAwaitingKeyBinding)
        let all = RustEngineConnectionFlags(rawValue: 63)
        XCTAssertTrue(all.isNetworkAvailable && all.isConnected && all.isUpdatingConnectionContext && all.isPerformingServiceTasks && all.proxyHasConnectionIssues && all.isAwaitingKeyBinding)
        let binding = RustEngineConnectionFlags(rawValue: 1 | 2 | 4 | 32)
        XCTAssertTrue(binding.isUpdatingConnectionContext && binding.isAwaitingKeyBinding)
        let connected = RustEngineConnectionFlags(rawValue: 1 | 2)
        XCTAssertTrue(connected.isNetworkAvailable)
        XCTAssertTrue(connected.isConnected)
        XCTAssertFalse(connected.isUpdatingConnectionContext)
        let proxyIssues = RustEngineConnectionFlags(rawValue: 1 | 16)
        XCTAssertTrue(proxyIssues.proxyHasConnectionIssues)
        XCTAssertFalse(proxyIssues.isConnected)
    }

    func testUpdatesTooLongDetection() {
        XCTAssertTrue(rustEngineIsUpdatesTooLong(Data([0x7e, 0xaf, 0x17, 0xe3])))
        XCTAssertTrue(rustEngineIsUpdatesTooLong(Data([0x7e, 0xaf, 0x17, 0xe3, 0x00])))
        XCTAssertFalse(rustEngineIsUpdatesTooLong(Data([0x7e, 0xaf, 0x17])))
        XCTAssertFalse(rustEngineIsUpdatesTooLong(Data([0x78, 0x2e, 0xe3, 0x74])))
        let sliced = Data([0xff, 0x7e, 0xaf, 0x17, 0xe3]).dropFirst()
        XCTAssertTrue(rustEngineIsUpdatesTooLong(sliced))
    }

    func testVerificationMapping() {
        XCTAssertEqual(RustEngineVerificationKind(rawValue: 1), .apns)
        XCTAssertEqual(RustEngineVerificationKind(rawValue: 2), .recaptcha)
        XCTAssertNil(RustEngineVerificationKind(rawValue: 3))
        XCTAssertEqual(RustEngineVerificationKind.apns.timeoutErrorText, "APNS_PUSH_TIMEOUT")
        XCTAssertEqual(RustEngineVerificationKind.recaptcha.timeoutErrorText, "RECAPTCHA_TIMEOUT")
        XCTAssertGreaterThan(RustEngineVerificationKind.timeout, 15.0)
    }

    func testOptionalText() {
        XCTAssertNil(rustEngineOptionalText(""))
        XCTAssertEqual(rustEngineOptionalText("FLOOD_WAIT_5"), "FLOOD_WAIT_5")
    }

    func testZeroSecondFloodWaitIsRetryable() {
        // MtProtoKit retries every FLOOD_WAIT_X / FLOOD_PREMIUM_WAIT_X the request's gate accepts,
        // X = 0 included. The engine delegates FLOOD_WAIT_0 with 0 seconds and the flood text.
        XCTAssertTrue(rustEngineRetryDecisionIsRetryable(code: 420, floodWaitText: rustEngineOptionalText("FLOOD_WAIT_0")))
        XCTAssertTrue(rustEngineRetryDecisionIsRetryable(code: 420, floodWaitText: rustEngineOptionalText("FLOOD_PREMIUM_WAIT_0")))
        XCTAssertTrue(rustEngineRetryDecisionIsRetryable(code: 420, floodWaitText: rustEngineOptionalText("FLOOD_WAIT_5")))
    }

    func testServerErrorsAreRetryableAndOtherDelegatedErrorsAreNot() {
        XCTAssertTrue(rustEngineRetryDecisionIsRetryable(code: 500, floodWaitText: nil))
        XCTAssertTrue(rustEngineRetryDecisionIsRetryable(code: -500, floodWaitText: nil))
        // Decided on the event at hand, never on a flood wait an earlier attempt reported.
        XCTAssertFalse(rustEngineRetryDecisionIsRetryable(code: -503, floodWaitText: rustEngineOptionalText("")))
        XCTAssertFalse(rustEngineRetryDecisionIsRetryable(code: 400, floodWaitText: nil))
    }

    func testMainSessionAuthorizationRequiredLogsOut() {
        // A main-session 401 must reach Network.loggedOut, as with MtProtoKit: a session terminated
        // from another device has to drop the account. Routing it through MTContext.checkIfLoggedOut
        // instead never logged out, because that probe completes on the session's own stored
        // temporary key without contacting the server.
        XCTAssertEqual(rustEngineAuthorizationRequiredAction(isMain: true), .logOut)
        XCTAssertEqual(rustEngineAuthorizationRequiredAction(isMain: false), .ignore)
    }

    func testOnlyNonCdnSessionsWithTemporaryKeysRunPfsInTheEngine() {
        XCTAssertTrue(rustEngineRunsPfs(isCdn: false, useTempAuthKeys: true, publicKeyCount: 1))
        XCTAssertFalse(rustEngineRunsPfs(isCdn: true, useTempAuthKeys: true, publicKeyCount: 1))
        XCTAssertFalse(rustEngineRunsPfs(isCdn: false, useTempAuthKeys: false, publicKeyCount: 1))
        XCTAssertFalse(rustEngineRunsPfs(isCdn: false, useTempAuthKeys: true, publicKeyCount: 0))
    }

    func testTemporaryKeyExpiryMovesBetweenLocalAndServerTime() {
        XCTAssertEqual(rustEngineServerExpiry(validUntil: 1_000_000, timeDifference: 12.7), 1_000_012)
        XCTAssertEqual(rustEngineLocalValidUntil(serverExpiry: 1_000_012, timeDifference: 12.7), 999_999)
        XCTAssertEqual(rustEngineServerExpiry(validUntil: Int32.max, timeDifference: 100.0), Int32.max)
    }

    func testAMadeTemporaryKeyReplacesOnlyAnOlderOrForeignOne() {
        let made = RustEngineTemporaryKeyInfo(keyId: 2, validUntil: 2000, boundTo: 7)
        XCTAssertTrue(rustEngineStoresTemporaryKey(stored: nil, made: made))
        XCTAssertFalse(rustEngineStoresTemporaryKey(stored: made, made: made), "the same key is kept as it is")
        XCTAssertTrue(rustEngineStoresTemporaryKey(stored: RustEngineTemporaryKeyInfo(keyId: 1, validUntil: 1000, boundTo: 7), made: made))
        XCTAssertFalse(rustEngineStoresTemporaryKey(stored: RustEngineTemporaryKeyInfo(keyId: 1, validUntil: 3000, boundTo: 7), made: made), "a longer-lived key of another session stays")
        XCTAssertTrue(rustEngineStoresTemporaryKey(stored: RustEngineTemporaryKeyInfo(keyId: 1, validUntil: 3000, boundTo: 8), made: made), "a key bound to another permanent key goes")
        XCTAssertFalse(rustEngineStoresTemporaryKey(stored: RustEngineTemporaryKeyInfo(keyId: 1, validUntil: 3000, boundTo: nil), made: made))
    }

    func testAKeptTemporaryKeyIsOfferedOnlyForItsPermanentKeyAndWithTimeLeft() {
        let kept = RustEngineTemporaryKeyInfo(keyId: 1, validUntil: 10_000, boundTo: 7)
        XCTAssertTrue(rustEngineOffersTemporaryKey(stored: kept, permanentKeyId: 7, now: 9_000, minimumLifetime: 300))
        XCTAssertFalse(rustEngineOffersTemporaryKey(stored: kept, permanentKeyId: 8, now: 9_000, minimumLifetime: 300))
        XCTAssertFalse(rustEngineOffersTemporaryKey(stored: kept, permanentKeyId: nil, now: 9_000, minimumLifetime: 300))
        XCTAssertFalse(rustEngineOffersTemporaryKey(stored: kept, permanentKeyId: 7, now: 9_800, minimumLifetime: 300))
        let legacy = RustEngineTemporaryKeyInfo(keyId: 1, validUntil: 10_000, boundTo: nil)
        XCTAssertTrue(rustEngineOffersTemporaryKey(stored: legacy, permanentKeyId: 7, now: 9_000, minimumLifetime: 300), "MtProtoKit's keys carry no binding")
        let permanent = RustEngineTemporaryKeyInfo(keyId: 1, validUntil: Int32.max, boundTo: nil)
        XCTAssertFalse(rustEngineOffersTemporaryKey(stored: permanent, permanentKeyId: 7, now: 9_000, minimumLifetime: 300))
    }

    func testALostAnswerKeepsTheCallWaiting() {
        XCTAssertTrue(rustEngineKeepsWaitingAfterLostAnswer(code: 500, text: "PROTOCOL_ERROR_ANSWER_LOST"))
        XCTAssertFalse(rustEngineKeepsWaitingAfterLostAnswer(code: 500, text: "PROTOCOL_ERROR_REJECTED"))
        XCTAssertFalse(rustEngineKeepsWaitingAfterLostAnswer(code: 400, text: "PROTOCOL_ERROR_ANSWER_LOST"))
        XCTAssertFalse(rustEngineResubmitsAfterKeyRotation(code: 500, text: "PROTOCOL_ERROR_ANSWER_LOST"))
    }

    func testOnlyARotatedTemporaryKeyFailureIsResubmitted() {
        XCTAssertTrue(rustEngineResubmitsAfterKeyRotation(code: 500, text: "TEMP_KEY_ROTATED"))
        XCTAssertFalse(rustEngineResubmitsAfterKeyRotation(code: 500, text: "INTERNAL"))
        XCTAssertFalse(rustEngineResubmitsAfterKeyRotation(code: 400, text: "TEMP_KEY_ROTATED"))
        var state = RustEngineErrorState()
        XCTAssertEqual(state.applyServerError().internalServerErrorCount, 1)
        state.didResubmit()
        XCTAssertEqual(state.applyServerError().internalServerErrorCount, 2, "each rotation counts as a server error for the request's policy")
    }

    func testTheNetworkFingerprintIgnoresTunnelsAndHostBits() {
        let wifi = RustEngineNetworkInterface(name: "en0", address: [192, 168, 1, 23], netmask: [255, 255, 255, 0])
        let otherHost = RustEngineNetworkInterface(name: "en0", address: [192, 168, 1, 77], netmask: [255, 255, 255, 0])
        let vpn = RustEngineNetworkInterface(name: "utun3", address: [10, 8, 0, 2], netmask: [255, 255, 255, 0])
        let virtualMachine = RustEngineNetworkInterface(name: "vmnet8", address: [172, 16, 5, 1], netmask: [255, 255, 255, 0])
        let linkLocal6 = RustEngineNetworkInterface(name: "en0", address: [0xfe, 0x80] + Array(repeating: 1, count: 14), netmask: [])
        let global6 = RustEngineNetworkInterface(name: "en0", address: [0x2a, 0x01, 0x04, 0xf8, 0x0c, 0x17, 0x1b, 0x2c] + Array(repeating: 7, count: 8), netmask: [])
        let router = RustEngineNetworkRouter(interface: "en0", address: "192.168.1.1")
        let vpnRouter = RustEngineNetworkRouter(interface: "utun3", address: "10.8.0.1")
        let base = rustEngineNetworkFingerprint(interfaces: [wifi], routers: [router])
        XCTAssertEqual(base, "en0 192.168.1.0/24\nrouter en0 192.168.1.1")
        XCTAssertEqual(rustEngineNetworkFingerprint(interfaces: [otherHost], routers: [router]), base, "another address on the same network")
        XCTAssertEqual(rustEngineNetworkFingerprint(interfaces: [wifi, vpn, virtualMachine, linkLocal6], routers: [router, vpnRouter]), base, "a VPN, a virtual machine link or a link-local address changes nothing")
        XCTAssertNotEqual(rustEngineNetworkFingerprint(interfaces: [wifi, global6], routers: [router]), base, "the IPv6 prefix tells same-looking home networks apart")
        XCTAssertNotEqual(rustEngineNetworkFingerprint(interfaces: [wifi], routers: [RustEngineNetworkRouter(interface: "en0", address: "192.168.1.254")]), base)
        XCTAssertNil(rustEngineNetworkFingerprint(interfaces: [vpn, linkLocal6], routers: [vpnRouter]), "nothing identifies the network")
    }

    func testCellularIsOneNetworkAndDoesNotDisturbWifi() {
        let wifi = RustEngineNetworkInterface(name: "en0", address: [192, 168, 1, 23], netmask: [255, 255, 255, 0])
        let attach = RustEngineNetworkInterface(name: "pdp_ip0", address: [10, 42, 7, 9], netmask: [255, 255, 255, 255])
        let reattach = RustEngineNetworkInterface(name: "pdp_ip0", address: [10, 51, 3, 200], netmask: [255, 255, 255, 255])
        let router = RustEngineNetworkRouter(interface: "en0", address: "192.168.1.1")
        XCTAssertEqual(rustEngineNetworkFingerprint(interfaces: [wifi, attach], routers: [router]), rustEngineNetworkFingerprint(interfaces: [wifi], routers: [router]), "cellular staying up next to Wi-Fi changes nothing")
        XCTAssertEqual(rustEngineNetworkFingerprint(interfaces: [attach], routers: []), "cellular")
        XCTAssertEqual(rustEngineNetworkFingerprint(interfaces: [reattach], routers: []), "cellular", "a new attach is the same network")
    }

    func testOnlyRoutersOfTheNetworkItselfCount() {
        XCTAssertTrue(rustEngineNetworkRouterCounts(RustEngineNetworkRouter(interface: "en0", address: "192.168.1.1")))
        XCTAssertFalse(rustEngineNetworkRouterCounts(RustEngineNetworkRouter(interface: "utun4", address: "10.8.0.1")), "a VPN's router never resolves and never names the network")
        XCTAssertFalse(rustEngineNetworkRouterCounts(RustEngineNetworkRouter(interface: "ppp0", address: "10.0.0.1")))
        XCTAssertFalse(rustEngineNetworkRouterCounts(RustEngineNetworkRouter(interface: "pdp_ip0", address: "10.64.0.1")))
        XCTAssertFalse(rustEngineNetworkRouterCounts(RustEngineNetworkRouter(interface: "en0", address: "")))
    }
}
