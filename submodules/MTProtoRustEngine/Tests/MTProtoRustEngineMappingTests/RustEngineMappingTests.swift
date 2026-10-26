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

    func testEngineThreadsAreToldApartByName() {
        XCTAssertTrue(rustEngineOwnsThread(named: "mtproto-main"))
        XCTAssertTrue(rustEngineOwnsThread(named: "mtproto-worker-3"))
        XCTAssertTrue(rustEngineOwnsThread(named: "mtproto-resolver"))
        XCTAssertFalse(rustEngineOwnsThread(named: ""))
        XCTAssertFalse(rustEngineOwnsThread(named: "main"))
        XCTAssertFalse(rustEngineOwnsThread(named: "com.apple.NSURLSession-work"))
        XCTAssertFalse(rustEngineOwnsThread(named: "MTProto"))
    }

    private static let bridgeQueueLabels: Set<String> = [
        "org.telegram.MTProtoRust.streams",
        "org.telegram.MTProtoRust.carrier",
        "org.telegram.MTProtoRust.session",
        "org.telegram.MTProtoRust.network",
    ]

    func testBridgeQueuesAreToldApartByLabel() {
        for label in RustEngineMappingTests.bridgeQueueLabels {
            XCTAssertTrue(rustEngineOwnsQueue(label: label), label)
        }
        XCTAssertFalse(rustEngineOwnsQueue(label: ""))
        XCTAssertFalse(rustEngineOwnsQueue(label: "com.apple.main-thread"))
        XCTAssertFalse(rustEngineOwnsQueue(label: "com.apple.root.default-qos"))
        XCTAssertFalse(rustEngineOwnsQueue(label: "org.telegram.Telegram.trace"))
        XCTAssertFalse(rustEngineOwnsQueue(label: "org.telegram.MTProtoRust"))
        XCTAssertFalse(rustEngineOwnsQueue(label: "org.telegram.MTProtoRustX.session"))
        XCTAssertFalse(rustEngineOwnsQueue(label: "mtproto-main"))
    }

    /// Pins the labels the bridge really creates its queues with: every queue made anywhere under
    /// `Sources/MTProtoRustEngine` has a literal label, the labels are these four, and each is recognized.
    func testEveryBridgeQueueIsRecognized() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MTProtoRustEngine")
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))
        let files = enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        XCTAssertGreaterThan(files.count, 5)
        let creation = try NSRegularExpression(pattern: #"\b(?:DispatchQueue|Queue)\(|dispatch_queue_create\("#)
        let labelled = try NSRegularExpression(pattern: #"\b(?:DispatchQueue\(label|Queue\(name): "([^"\\]*)"[,)]"#)
        var creations: [String] = []
        var labels: [String] = []
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            let range = NSRange(text.startIndex..., in: text)
            for match in creation.matches(in: text, range: range) {
                creations.append("\(file.lastPathComponent) at \(match.range.location)")
            }
            for match in labelled.matches(in: text, range: range) {
                labels.append(String(text[Range(match.range(at: 1), in: text)!]))
            }
        }
        XCTAssertEqual(labels.count, creations.count, "every bridge queue needs a literal label: \(creations)")
        XCTAssertEqual(Set(labels), RustEngineMappingTests.bridgeQueueLabels)
        for label in labels {
            XCTAssertTrue(rustEngineOwnsQueue(label: label), label)
        }
    }

    func testCreatedKeysAreToldApartByTheirFlags() {
        XCTAssertEqual(RustEngineAuthKeyCreatedFlags.temporary, 1)
        XCTAssertEqual(RustEngineAuthKeyCreatedFlags.permanent, 2)
        XCTAssertEqual(rustEngineCreatedKeyKind(flags: 1), .temporary)
        XCTAssertEqual(rustEngineCreatedKeyKind(flags: 2), .permanent)
        XCTAssertNil(rustEngineCreatedKeyKind(flags: 0), "an engine before ABI 4 says neither")
        XCTAssertNil(rustEngineCreatedKeyKind(flags: 3))
    }

    func testOnlyEncryptedMessageInvalidSaysTheProbedKeyIsUnknown() {
        XCTAssertEqual(rustEngineKeyProbeOutcome(code: 400, text: "ENCRYPTED_MESSAGE_INVALID"), .keyUnknown)
        XCTAssertEqual(rustEngineKeyProbeOutcome(code: 500, text: "INTERNAL_SERVER_ERROR"), .retrying)
        XCTAssertEqual(rustEngineKeyProbeOutcome(code: 420, text: "FLOOD_WAIT_3"), .retrying)
        XCTAssertEqual(rustEngineKeyProbeOutcome(code: -503, text: "Timeout"), .retrying)
        XCTAssertEqual(rustEngineKeyProbeOutcome(code: 400, text: "TEMP_AUTH_KEY_EMPTY"), .noVerdict)
        XCTAssertEqual(rustEngineKeyProbeOutcome(code: 400, text: "CONNECTION_NOT_INITED"), .noVerdict)
        XCTAssertEqual(rustEngineKeyProbeOutcome(code: 401, text: "ENCRYPTED_MESSAGE_INVALID"), .noVerdict)
        XCTAssertEqual(rustEngineKeyProbeOutcome(code: 406, text: "AUTH_KEY_DUPLICATED"), .noVerdict)
    }

    func testAnUnknownPermanentKeyNeedsEveryPieceOfEvidence() {
        let now = 10_000.0
        let window = RustEnginePermanentKeyEvidence.observationWindow
        let confirmed = RustEnginePermanentKeyEvidence(reportedKeyId: 7, reportedAt: now - 1.0, firstRefusalAt: now - window - 1.0, lastKnownAt: nil)
        XCTAssertNil(rustEnginePermanentKeyUnknownDenial(confirmed, probedKeyId: 7, now: now))

        var noReport = confirmed
        noReport.reportedKeyId = nil
        noReport.reportedAt = nil
        XCTAssertNotNil(rustEnginePermanentKeyUnknownDenial(noReport, probedKeyId: 7, now: now), "the engine did not report the key")
        XCTAssertNotNil(rustEnginePermanentKeyUnknownDenial(confirmed, probedKeyId: 8, now: now), "the report is about another key")
        var oldReport = confirmed
        oldReport.reportedAt = now - RustEnginePermanentKeyEvidence.maximumReportAge - 1.0
        XCTAssertNotNil(rustEnginePermanentKeyUnknownDenial(oldReport, probedKeyId: 7, now: now), "the report is too old")
        var futureReport = confirmed
        futureReport.reportedAt = now + 30.0
        XCTAssertNotNil(rustEnginePermanentKeyUnknownDenial(futureReport, probedKeyId: 7, now: now), "a clock set back is no evidence")
        var noRefusal = confirmed
        noRefusal.firstRefusalAt = nil
        XCTAssertNotNil(rustEnginePermanentKeyUnknownDenial(noRefusal, probedKeyId: 7, now: now), "no session saw a refused bind")
        var tooSoon = confirmed
        tooSoon.firstRefusalAt = now - window + 1.0
        XCTAssertNotNil(rustEnginePermanentKeyUnknownDenial(tooSoon, probedKeyId: 7, now: now), "the key was not watched long enough")
        var answered = confirmed
        answered.lastKnownAt = now - 5.0
        XCTAssertNotNil(rustEnginePermanentKeyUnknownDenial(answered, probedKeyId: 7, now: now), "a call was answered under the key")
    }

    func testAKeyTheServerKnewWithinADayIsNeverValidated() {
        let now = 1_000_000.0
        let immunity = RustEnginePermanentKeyEvidence.immunity
        var evidence = RustEnginePermanentKeyEvidence(reportedKeyId: 7, reportedAt: now - 1.0, firstRefusalAt: now - 20.0, lastKnownAt: now - 25.0)
        XCTAssertNotNil(rustEnginePermanentKeyUnknownDenial(evidence, probedKeyId: 7, now: now), "answered just before the refusals: tdlib's immunity")
        evidence.lastKnownAt = now - immunity + 60.0
        XCTAssertNotNil(rustEnginePermanentKeyUnknownDenial(evidence, probedKeyId: 7, now: now), "answered almost a day ago")
        evidence.lastKnownAt = now + 5.0
        XCTAssertNotNil(rustEnginePermanentKeyUnknownDenial(evidence, probedKeyId: 7, now: now), "answered while the decision was made")
        evidence.lastKnownAt = now - immunity - 1.0
        XCTAssertNil(rustEnginePermanentKeyUnknownDenial(evidence, probedKeyId: 7, now: now), "more than a day ago: validated")
        evidence.lastKnownAt = nil
        XCTAssertNil(rustEnginePermanentKeyUnknownDenial(evidence, probedKeyId: 7, now: now), "never in this context: validated")
    }

    func testRefusalsLongApartStartANewEpisode() {
        let gap = RustEnginePermanentKeyEvidence.refusalEpisodeGap
        XCTAssertTrue(rustEngineRefusalContinuesEpisode(lastRefusalAt: 100.0, at: 100.0 + gap))
        XCTAssertFalse(rustEngineRefusalContinuesEpisode(lastRefusalAt: 100.0, at: 100.0 + gap + 1.0), "a refusal long ago, with the key working since, is another episode")
        XCTAssertFalse(rustEngineRefusalContinuesEpisode(lastRefusalAt: 100.0, at: 50.0), "a clock set back starts over")
    }

    func testTheVerdictWaitsForTheObservationWindow() {
        let window = RustEnginePermanentKeyEvidence.observationWindow
        XCTAssertEqual(rustEnginePermanentKeyDecisionDelay(firstRefusalAt: nil, now: 100.0), 0.0)
        XCTAssertEqual(rustEnginePermanentKeyDecisionDelay(firstRefusalAt: 100.0, now: 100.0), window)
        XCTAssertEqual(rustEnginePermanentKeyDecisionDelay(firstRefusalAt: 100.0, now: 104.0), window - 4.0)
        XCTAssertEqual(rustEnginePermanentKeyDecisionDelay(firstRefusalAt: 100.0, now: 100.0 + window + 5.0), 0.0)
        XCTAssertEqual(rustEnginePermanentKeyDecisionDelay(firstRefusalAt: 1_000.0, now: 100.0), window, "a clock set back never waits longer than the window")
    }

    func testImportedBytesAreNeverSentTwice() {
        XCTAssertEqual(rustEngineImportFailureAction(code: 400, text: "AUTH_BYTES_INVALID", exportsSoFar: 1), .exportAgain)
        XCTAssertEqual(rustEngineImportFailureAction(code: 500, text: "TEMP_KEY_ROTATED", exportsSoFar: 1), .exportAgain)
        XCTAssertEqual(rustEngineImportFailureAction(code: 500, text: "INTERDC_2_CALL_ERROR", exportsSoFar: 1), .exportAgain)
        XCTAssertEqual(rustEngineImportFailureAction(code: 400, text: "AUTH_BYTES_INVALID", exportsSoFar: rustEngineTransferExportsPerAttempt), .fail, "one fresh export per attempt; MTContext's backoff does the rest")
        XCTAssertEqual(rustEngineImportFailureAction(code: 401, text: "AUTH_KEY_UNREGISTERED", exportsSoFar: 1), .fail)
        XCTAssertEqual(rustEngineImportFailureAction(code: 400, text: "DC_ID_INVALID", exportsSoFar: 1), .fail)
        XCTAssertTrue(rustEngineTransferRetries(isImport: false, floodWaitErrorText: nil), "a server error on the export is retried")
        XCTAssertFalse(rustEngineTransferRetries(isImport: true, floodWaitErrorText: nil), "the same import bytes are not sent again")
        XCTAssertTrue(rustEngineTransferRetries(isImport: true, floodWaitErrorText: "FLOOD_WAIT_2"), "flood waits are waited out")
    }

    func testTheImportingSessionWaitsForNoToken() {
        XCTAssertTrue(rustEngineRequiresForeignAuthToken(isMain: false, isCdn: false, datacenterId: 4, masterDatacenterId: 2))
        XCTAssertFalse(rustEngineRequiresForeignAuthToken(isMain: false, isCdn: false, datacenterId: 4, masterDatacenterId: 2, importsAuthorization: true))
        XCTAssertEqual(rustEngineSessionRole(isMain: false, isCdn: false, datacenterId: 4, masterDatacenterId: 2, importsAuthorization: true), .worker)
        XCTAssertEqual(rustEngineSessionRole(isMain: false, isCdn: false, datacenterId: 4, masterDatacenterId: 2), .workerRequiringAuthToken)
    }

    func testOnlyTheServersOwnAnswersCountAsEvidence() {
        XCTAssertTrue(rustEngineFailureIsServerAnswer(code: 400, text: "PEER_ID_INVALID"))
        XCTAssertTrue(rustEngineFailureIsServerAnswer(code: 420, text: "FLOOD_WAIT_3"))
        XCTAssertTrue(rustEngineFailureIsServerAnswer(code: 500, text: "INTERDC_2_CALL_ERROR"))
        XCTAssertTrue(rustEngineFailureIsServerAnswer(code: 403, text: "CHAT_WRITE_FORBIDDEN"))
        XCTAssertFalse(rustEngineFailureIsServerAnswer(code: 401, text: "AUTH_KEY_UNREGISTERED"), "a temporary key of a destroyed permanent key still answers 401")
        XCTAssertFalse(rustEngineFailureIsServerAnswer(code: 500, text: "TEMP_KEY_ROTATED"))
        XCTAssertFalse(rustEngineFailureIsServerAnswer(code: 500, text: "SESSION_RESET"), "the engine's, for a call retired with its session")
        XCTAssertTrue(rustEngineFailureIsServerAnswer(code: 500, text: "RESPONSE_UNPACK_FAILED: gzip"), "an answer the server encrypted under the key, though unreadable")
        XCTAssertTrue(rustEngineFailureIsServerAnswer(code: 500, text: "TL_PARSING_ERROR"))
        XCTAssertFalse(rustEngineFailureIsServerAnswer(code: 500, text: "PROTOCOL_ERROR_ANSWER_LOST"))
        XCTAssertFalse(rustEngineFailureIsServerAnswer(code: 500, text: "PROTOCOL_ERROR_BAD_MSG_32"))
        XCTAssertFalse(rustEngineFailureIsServerAnswer(code: 400, text: "REQUEST_INVALID_SIZE"))
        XCTAssertFalse(rustEngineFailureIsServerAnswer(code: 403, text: "APNS_PUSH_TIMEOUT"))
        XCTAssertFalse(rustEngineFailureIsServerAnswer(code: -503, text: "Timeout"))
        XCTAssertFalse(rustEngineFailureIsServerAnswer(code: 403, text: ""))
    }

    func testAnyAnswerUnderThePermanentKeyItselfCountsForItsValidation() {
        XCTAssertTrue(rustEngineFailureIsAnswerUnderKey(code: 401, text: "AUTH_KEY_UNREGISTERED"), "under the permanent key itself, a 401 is the server's answer")
        XCTAssertTrue(rustEngineFailureIsAnswerUnderKey(code: 420, text: "FLOOD_WAIT_3"))
        XCTAssertTrue(rustEngineFailureIsAnswerUnderKey(code: 500, text: "INTERNAL_SERVER_ERROR"))
        XCTAssertFalse(rustEngineFailureIsAnswerUnderKey(code: 400, text: "REQUEST_INVALID_SIZE"), "the engine's own refusal to send")
        XCTAssertFalse(rustEngineFailureIsAnswerUnderKey(code: 400, text: "REQUEST_ID_INVALID"))
        XCTAssertFalse(rustEngineFailureIsAnswerUnderKey(code: 500, text: "SESSION_RESET"))
        XCTAssertFalse(rustEngineFailureIsAnswerUnderKey(code: -404, text: "AUTH_KEY_INVALID"), "a transport error")
        XCTAssertTrue(rustEngineFailureIsAnswerUnderKey(code: 500, text: "PROTOCOL_ERROR_BAD_MSG_32"), "raised after the server's bad_msg_notifications under the key")
        XCTAssertTrue(rustEngineFailureIsAnswerUnderKey(code: 500, text: "RESPONSE_UNPACK_FAILED: gzip"))
    }
}
