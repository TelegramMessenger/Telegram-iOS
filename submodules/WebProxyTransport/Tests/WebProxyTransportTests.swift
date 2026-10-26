import XCTest
@testable import WebProxyTransport

final class WebProxyTransportTests: XCTestCase {
    func testServerControlHandshakeSequence() throws {
        let nonce = String(repeating: "A", count: 43)
        XCTAssertEqual(
            try WebProxyControlMessage.decode(#"{"t":"status","state":"connecting"}"#),
            .status(.connecting)
        )
        XCTAssertEqual(
            try WebProxyControlMessage.decode(#"{"t":"tproxy-android-init","v":1,"nonce":"\#(nonce)"}"#),
            .initialize(nonce: nonce)
        )

        let hello = WebProxyFrame(type: .hello, streamId: 0, payload: Data([1]))
        XCTAssertEqual(try hello.validated(), hello)
        let welcome = WebProxyFrame(type: .welcome, streamId: 0)
        XCTAssertEqual(try WebProxyFrameDecoder().append(WebProxyFrameEncoder.encode(welcome)), [welcome])
    }

    func testAdvisoryControlMessages() throws {
        for status in WebProxyPageStatus.allCases {
            XCTAssertEqual(
                try WebProxyControlMessage.decode(#"{"state":"\#(status.rawValue)","t":"status"}"#),
                .status(status)
            )
        }
        XCTAssertEqual(
            try WebProxyControlMessage.decode(#"{"down":2097152,"t":"traffic","up":0}"#),
            .traffic(up: 0, down: 2 * 1024 * 1024)
        )
        XCTAssertEqual(try WebProxyControlMessage.decode(#"{"t":"close"}"#), .close)
    }

    func testMalformedControlMessagesAreRejected() {
        let nonce = String(repeating: "A", count: 43)
        let invalidMessages = [
            "not-json",
            #"{"t":"unknown"}"#,
            #"{"t":"status","state":"ready"}"#,
            #"{"t":"status","state":"connecting","extra":1}"#,
            #"{"t":"traffic","up":-1,"down":0}"#,
            #"{"t":"traffic","up":1.5,"down":0}"#,
            #"{"t":"traffic","up":true,"down":0}"#,
            #"{"t":"traffic","up":33554433,"down":0}"#,
            #"{"t":"close","reason":"provider-controlled"}"#,
            #"{"t":"tproxy-android-init","v":2,"nonce":"\#(nonce)"}"#,
            #"{"t":"tproxy-android-init","v":true,"nonce":"\#(nonce)"}"#,
            #"{"t":"tproxy-android-init","v":1,"nonce":"short"}"#
        ]
        for value in invalidMessages {
            XCTAssertThrowsError(try WebProxyControlMessage.decode(value), value)
        }
    }

    private func plainSecret() throws -> Data {
        return try XCTUnwrap(WebProxyConfiguration.parseSecret("000102030405060708090a0b0c0d0e0f"))
    }

    private func paddedSecret() throws -> Data {
        return try XCTUnwrap(WebProxyConfiguration.parseSecret("dd000102030405060708090a0b0c0d0e0f"))
    }

    func testCapabilityVectors() throws {
        let plain = try XCTUnwrap(WebProxyConfiguration(
            host: "PROXY.EXAMPLE.COM",
            secret: try self.plainSecret()
        ))
        XCTAssertEqual(plain.host, "proxy.example.com")
        XCTAssertEqual(plain.path, "")
        XCTAssertEqual(plain.bridgeCapability(), "MHLEY5PmW1GWqJkSrlmJpvJUiLhBH_QKy6yKg8a0JPk")

        let padded = try XCTUnwrap(WebProxyConfiguration(
            host: "proxy.example.com",
            secret: try self.paddedSecret()
        ))
        XCTAssertEqual(padded.bridgeCapability(), "IpJrt3e7sKtzPyoXy6w-Zj6GGEvsvclN66JzQEfPYLA")

        let prefixed = try XCTUnwrap(WebProxyConfiguration(
            host: "PROXY.EXAMPLE.COM",
            path: "dobry-cola-super-app",
            secret: try self.plainSecret()
        ))
        XCTAssertEqual(prefixed.address, "proxy.example.com/dobry-cola-super-app")
        XCTAssertEqual(prefixed.bridgeCapability(), "hHz99Xs93EN1j91G9gpNepXwGNNt5YdAFkEVk_LlqdQ")

        let prefixedPadded = try XCTUnwrap(WebProxyConfiguration(
            host: "proxy.example.com",
            path: "dobry-cola-super-app",
            secret: try self.paddedSecret()
        ))
        XCTAssertEqual(prefixedPadded.bridgeCapability(), "TGUkZaevsavLbHvlNWipnRoYxgzZ51ioWvbxgGT3wHo")
    }

    func testCapabilityIsBoundToThePath() throws {
        let secret = try self.plainSecret()
        let capability: (String) throws -> String = { path in
            try XCTUnwrap(WebProxyConfiguration(host: "proxy.example.com", path: path, secret: secret)).bridgeCapability()
        }
        let root = try capability("")
        let first = try capability("dobry-cola-super-app")
        let second = try capability("other-app")
        let nested = try capability("dobry-cola-super-app/v2")
        let uppercased = try capability("Dobry-Cola-Super-App")
        XCTAssertEqual(Set([root, first, second, nested, uppercased]).count, 5)
    }

    func testAddressParsing() throws {
        let parsed = try XCTUnwrap(WebProxyConfiguration.canonicalAddress(" Proxy.Example.COM/My-App "))
        XCTAssertEqual(parsed.host, "proxy.example.com")
        XCTAssertEqual(parsed.path, "My-App")

        XCTAssertEqual(WebProxyConfiguration.canonicalAddress("proxy.example.com/slug/")?.path, "slug")
        XCTAssertEqual(WebProxyConfiguration.canonicalAddress("proxy.example.com/")?.path, "")
        XCTAssertEqual(WebProxyConfiguration.canonicalAddress("proxy.example.com")?.path, "")
        XCTAssertEqual(WebProxyConfiguration.canonicalAddress("proxy.example.com/a/b/c")?.path, "a/b/c")
        XCTAssertEqual(WebProxyConfiguration.canonicalAddress("proxy.example.com/a_b-9")?.path, "a_b-9")

        let invalid = [
            "/slug",
            "proxy.example.com//a",
            "proxy.example.com//",
            "proxy.example.com/a//b",
            "proxy.example.com/-a",
            "proxy.example.com/_a",
            "proxy.example.com/a%2Fb",
            "proxy.example.com/a.b",
            "proxy.example.com/.",
            "proxy.example.com/..",
            "proxy.example.com/a b",
            "proxy.example.com/\u{e4}",
            "proxy.example.com/a/" + String(repeating: "b", count: 128),
            "proxy.example.com:8443/slug",
            "127.0.0.1/slug"
        ]
        for value in invalid {
            XCTAssertNil(WebProxyConfiguration.canonicalAddress(value), value)
        }

        XCTAssertEqual(WebProxyConfiguration.canonicalPath(String(repeating: "a", count: 128)), String(repeating: "a", count: 128))
        XCTAssertNil(WebProxyConfiguration.canonicalPath(String(repeating: "a", count: 129)))
    }

    func testBridgeURLUsesTheBase() throws {
        let nonce = String(repeating: "A", count: 43)
        let root = try XCTUnwrap(WebProxyConfiguration(host: "proxy.example.com", secret: try self.plainSecret()))
        XCTAssertEqual(root.base, "/")
        XCTAssertEqual(
            root.bridgeURL(nonce: nonce)?.absoluteString,
            "https://proxy.example.com/?bridge=MHLEY5PmW1GWqJkSrlmJpvJUiLhBH_QKy6yKg8a0JPk#android=\(nonce)"
        )

        let prefixed = try XCTUnwrap(WebProxyConfiguration(host: "proxy.example.com", path: "dobry-cola-super-app", secret: try self.plainSecret()))
        XCTAssertEqual(prefixed.base, "/dobry-cola-super-app/")
        XCTAssertEqual(
            prefixed.bridgeURL(nonce: nonce)?.absoluteString,
            "https://proxy.example.com/dobry-cola-super-app/?bridge=hHz99Xs93EN1j91G9gpNepXwGNNt5YdAFkEVk_LlqdQ#android=\(nonce)"
        )
    }

    func testSecretAndHostValidation() {
        XCTAssertNotNil(WebProxyConfiguration.parseSecret("000102030405060708090a0b0c0d0e0f"))
        XCTAssertNotNil(WebProxyConfiguration.parseSecret("dd000102030405060708090a0b0c0d0e0f"))
        XCTAssertNil(WebProxyConfiguration.parseSecret("ee000102030405060708090a0b0c0d0e0f"))
        XCTAssertNil(WebProxyConfiguration.parseSecret("00"))
        XCTAssertNil(WebProxyConfiguration.canonicalHost("user@example.com"))
        XCTAssertNil(WebProxyConfiguration.canonicalHost("example.com:8443"))
        XCTAssertEqual(WebProxyConfiguration.canonicalHost("Example.COM"), "example.com")
        XCTAssertEqual(WebProxyConfiguration.canonicalHost("BÜCHER.example"), "xn--bcher-kva.example")
        XCTAssertNil(WebProxyConfiguration.canonicalHost("127.0.0.1"))
        XCTAssertNil(WebProxyConfiguration.canonicalHost("127.1"))
        XCTAssertNil(WebProxyConfiguration.canonicalHost("0x7f.1"))
        XCTAssertNil(WebProxyConfiguration.canonicalHost("0177.0.0.1"))
        XCTAssertNil(WebProxyConfiguration.canonicalHost("1.2.3"))
        XCTAssertNil(WebProxyConfiguration.canonicalHost("proxy.example.com/slug"))
        XCTAssertEqual(WebProxyConfiguration.canonicalHost("3com.example"), "3com.example")
    }

    func testMarkedSecretRoundTrip() throws {
        // BASE_PATH.md §3: `{ printf '\x70'; printf <secret> } | base64 | tr '+/' '-_' | tr -d '=\n'`
        let vector = try XCTUnwrap(WebProxyConfiguration.parseMarkedSecret("cIVhlEBk_HMMv6RHNWLY7Fk"))
        XCTAssertTrue(vector.isMarked)
        XCTAssertEqual(vector.secret.map { String(format: "%02x", $0) }.joined(), "8561944064fc730cbfa4473562d8ec59")
        XCTAssertEqual(WebProxyConfiguration.linkSecretString(vector.secret, path: "phcf2vfe7zgbrslg"), "cIVhlEBk_HMMv6RHNWLY7Fk")
        XCTAssertEqual(WebProxyConfiguration.linkSecretString(vector.secret, path: ""), "8561944064fc730cbfa4473562d8ec59")

        for hex in ["000102030405060708090a0b0c0d0e0f", "dd000102030405060708090a0b0c0d0e0f"] {
            let secret = try XCTUnwrap(WebProxyConfiguration.parseSecret(hex))
            let marked = WebProxyConfiguration.linkSecretString(secret, path: "slug")
            let decoded = try XCTUnwrap(WebProxyConfiguration.parseMarkedSecret(marked))
            XCTAssertTrue(decoded.isMarked)
            XCTAssertEqual(decoded.secret, secret)
            // The plain form decodes to the same bytes and reports itself unmarked.
            XCTAssertEqual(try XCTUnwrap(WebProxyConfiguration.parseMarkedSecret(hex)).isMarked, false)
        }

        // A marked secret never changes the capability: the marker is a link encoding.
        let plain = try XCTUnwrap(WebProxyConfiguration(host: "proxy.example.com", path: "dobry-cola-super-app", secret: try self.plainSecret()))
        let viaMarker = try XCTUnwrap(WebProxyConfiguration(
            host: "proxy.example.com",
            path: "dobry-cola-super-app",
            secret: try XCTUnwrap(WebProxyConfiguration.parseSecret("cAABAgMEBQYHCAkKCwwNDg8"))
        ))
        XCTAssertEqual(plain, viaMarker)
        XCTAssertEqual(viaMarker.bridgeCapability(), "hHz99Xs93EN1j91G9gpNepXwGNNt5YdAFkEVk_LlqdQ")

        // 0xDD is never the marker, and a marker with a non-secret remainder is rejected.
        XCTAssertEqual(try XCTUnwrap(WebProxyConfiguration.parseSecret("dd000102030405060708090a0b0c0d0e0f")).count, 17)
        XCTAssertNil(WebProxyConfiguration.parseSecret("70000102030405060708090a0b0c0d"))
        XCTAssertNil(WebProxyConfiguration.parseSecret(""))
    }

    func testFrameGoldenVectorAndFragmentation() throws {
        let frame = WebProxyFrame(type: .data, streamId: 0x010203, payload: Data([0xaa, 0xbb]))
        let encoded = try WebProxyFrameEncoder.encode(frame)
        XCTAssertEqual(encoded, Data([0x02, 0x01, 0x02, 0x03, 0, 0, 0, 2, 0xaa, 0xbb]))

        for split in 0 ..< encoded.count {
            let decoder = WebProxyFrameDecoder()
            XCTAssertEqual(try decoder.append(encoded.prefix(split)), [])
            XCTAssertEqual(try decoder.append(encoded.dropFirst(split)), [frame])
        }
    }

    func testEveryFrameType() throws {
        let frames: [WebProxyFrame] = [
            .init(type: .open, streamId: 1),
            .init(type: .data, streamId: 1, payload: Data([1])),
            .init(type: .close, streamId: 1),
            .window(streamId: 1, delta: 42),
            .init(type: .ping, streamId: 0, payload: Data([7])),
            .init(type: .pong, streamId: 0, payload: Data([7])),
            .init(type: .hello, streamId: 0, payload: Data([1])),
            .init(type: .welcome, streamId: 0),
            .init(type: .bye, streamId: 0, payload: Data("bye".utf8))
        ]
        let encoded = try frames.reduce(into: Data()) { result, frame in
            result.append(try WebProxyFrameEncoder.encode(frame))
        }
        XCTAssertEqual(try WebProxyFrameDecoder().append(encoded), frames)
    }

    func testMalformedFramesAreRejected() throws {
        XCTAssertThrowsError(try WebProxyFrameEncoder.encode(.init(type: .open, streamId: 0)))
        XCTAssertThrowsError(try WebProxyFrameEncoder.encode(.init(type: .data, streamId: 1)))
        XCTAssertThrowsError(try WebProxyFrameEncoder.encode(.window(streamId: 1, delta: 0)))

        var oversizedHeader = Data([0x02, 0, 0, 1, 0, 0x10, 0, 1])
        oversizedHeader.append(0)
        XCTAssertThrowsError(try WebProxyFrameDecoder().append(oversizedHeader))
    }

    func testLargeConcatenatedBatchIsDecoded() throws {
        let payload = Data(repeating: 0x5a, count: WebProxyProtocol.maximumDataPayload)
        let frames = (1 ... 20).map { WebProxyFrame(type: .data, streamId: UInt32($0), payload: payload) }
        let encoded = try frames.reduce(into: Data()) { result, frame in
            result.append(try WebProxyFrameEncoder.encode(frame))
        }
        XCTAssertGreaterThan(encoded.count, WebProxyProtocol.maximumPayload)
        XCTAssertEqual(try WebProxyFrameDecoder().append(encoded), frames)
    }

    func testBatchFrameLimitIsEnforced() throws {
        var encoded = Data()
        for streamId in 1 ... (WebProxyProtocol.maximumBatchFrames + 1) {
            encoded.append(try WebProxyFrameEncoder.encode(.init(type: .open, streamId: UInt32(streamId))))
        }
        XCTAssertThrowsError(try WebProxyFrameDecoder().append(encoded))
    }

    func testTruncatedAndRandomInputNeverEscapesDeclaredErrors() throws {
        var state: UInt64 = 0x1234_5678_9abc_def0
        func nextByte() -> UInt8 {
            state = state &* 6364136223846793005 &+ 1
            return UInt8(truncatingIfNeeded: state >> 32)
        }

        for length in 0 ... 512 {
            let bytes = Data((0 ..< length).map { _ in nextByte() })
            do {
                _ = try WebProxyFrameDecoder().append(bytes)
            } catch let error as WebProxyFrameError {
                XCTAssertTrue([.invalidFrame, .unknownType, .bufferLimitExceeded].contains(error))
            }
        }
    }
}
