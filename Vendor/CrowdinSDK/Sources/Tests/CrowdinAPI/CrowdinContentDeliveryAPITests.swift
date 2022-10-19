//
//  CrowdinContentDeliveryAPITests.swift
//  CrowdinSDK-Unit-CrowdinAPI_Tests
//
//  Created by Serhii Londar on 29.10.2019.
//

import XCTest
@testable import CrowdinSDK

class CrowdinContentDeliveryAPITests: XCTestCase {
    var session = URLSessionMock()
    // swiftlint:disable implicitly_unwrapped_optional
    var crowdinContentDeliveryAPI: CrowdinContentDeliveryAPI!
    let defaultTimeoutForExpectation = 2.0
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        crowdinContentDeliveryAPI = nil
    }

    func testCrowdinContentDeliveryAPIGetStrings() {
        let expectation = XCTestExpectation(description: "Wait for callback")

        crowdinContentDeliveryAPI = CrowdinContentDeliveryAPI(hash: "hash", session: session)
        let fileString = """
        key = value;
        """
        session.data = fileString.data(using: .utf8)
        
        var result: [String: String]? = nil
        crowdinContentDeliveryAPI.getStrings(filePath: "filePath", etag: nil, timestamp: nil) { (strings, _, _) in
            result = strings
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: defaultTimeoutForExpectation)
        
        XCTAssertNotNil(result)
        XCTAssert(result?.count == 1)
        XCTAssert(result?.contains(where: { $0 == "key" && $1 == "value" }) ?? false)
    }
    
    func testCrowdinContentDeliveryAPIGetStringsMapping() {
        let expectation = XCTestExpectation(description: "Wait for callback")
        
        crowdinContentDeliveryAPI = CrowdinContentDeliveryAPI(hash: "hash", session: session)
        let fileString = """
        key1 = 0;
        key2 = 1;
        """
        session.data = fileString.data(using: .utf8)
        
        var result: [String: String]? = nil
        crowdinContentDeliveryAPI.getStrings(filePath: "filePath", etag: nil, timestamp: nil) { (strings, _, _) in
            result = strings
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: defaultTimeoutForExpectation)
        
        XCTAssertNotNil(result)
        XCTAssert(result?.count == 2)
        XCTAssert(result?.contains(where: { $0 == "key1" && $1 == "0" }) ?? false)
        XCTAssert(result?.contains(where: { $0 == "key2" && $1 == "1" }) ?? false)
    }
    
    func testCrowdinContentDeliveryAPIGetPlurals() {
        let expectation = XCTestExpectation(description: "Wait for callback")
        
        crowdinContentDeliveryAPI = CrowdinContentDeliveryAPI(hash: "hash", session: session)
        let fileString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>johns_pineapples_count</key>
            <dict>
                <key>NSStringLocalizedFormatKey</key>
                <string>%#@v1_pineapples_count@</string>
                <key>v1_pineapples_count</key>
                <dict>
                    <key>NSStringFormatSpecTypeKey</key>
                    <string>NSStringPluralRuleType</string>
                    <key>NSStringFormatValueTypeKey</key>
                    <string>u</string>
                    <key>zero</key>
                    <string>John has no pineapples</string>
                    <key>one</key>
                    <string>John has 1 pineapple</string>
                    <key>other</key>
                    <string>John has %u pineapples</string>
                </dict>
            </dict>
        </dict>
        </plist>
        """
        session.data = fileString.data(using: .utf8)
        
        var result: [AnyHashable: Any]? = nil
        crowdinContentDeliveryAPI.getPlurals(filePath: "filePath", etag: nil, timestamp: nil) { (response, _, _) in
            result = response
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: defaultTimeoutForExpectation)
        
        XCTAssertNotNil(result)
        if let result = result {
            XCTAssert(result.isEmpty == false)
            XCTAssert(result["johns_pineapples_count"] != nil)
        }
    }
    
    func testCrowdinContentDeliveryAPIGetPluralsMapping() {
        let expectation = XCTestExpectation(description: "Wait for callback")
        
        crowdinContentDeliveryAPI = CrowdinContentDeliveryAPI(hash: "hash", session: session)
        let fileString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>johns_pineapples_count</key>
            <dict>
                <key>NSStringLocalizedFormatKey</key>
                <string>%#@v1_pineapples_count@</string>
                <key>v1_pineapples_count</key>
                <dict>
                    <key>NSStringFormatSpecTypeKey</key>
                    <string>NSStringPluralRuleType</string>
                    <key>NSStringFormatValueTypeKey</key>
                    <string>u</string>
                    <key>zero</key>
                    <string>111111</string>
                    <key>one</key>
                    <string>222222</string>
                    <key>other</key>
                    <string>333333</string>
                </dict>
            </dict>
        </dict>
        </plist>
        """
        session.data = fileString.data(using: .utf8)
        var result: [AnyHashable: Any]?
        
        crowdinContentDeliveryAPI.getPluralsMapping(filePath: "filePath", etag: nil, timestamp: nil) { (response, _) in
            result = response
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: defaultTimeoutForExpectation)
        
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.isEmpty == .some(false))
        XCTAssertNotNil(result?["johns_pineapples_count"])
    }
}
