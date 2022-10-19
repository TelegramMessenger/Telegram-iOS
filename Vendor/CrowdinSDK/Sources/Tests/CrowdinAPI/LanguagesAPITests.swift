//
//  LanguagesAPITests.swift
//  CrowdinSDK-Unit-CrowdinAPI_Tests
//
//  Created by Serhii Londar on 11.02.2020.
//

import XCTest
@testable import CrowdinSDK

class LanguagesAPITests: XCTestCase {
    var session = URLSessionMock()
    // swiftlint:disable implicitly_unwrapped_optional
    var api: LanguagesAPI!
    let defaultTimeoutForExpectation = 2.0
    
    var testOrganization = "test_organization"
    
    func testAPIInitialization() {
        api = LanguagesAPI()
        
        XCTAssert(api.baseURL == "https://crowdin.com/api/v2/")
        XCTAssert(api.apiPath == "languages")
        XCTAssertNil(api.organizationName)
        XCTAssert(api.fullPath == "https://crowdin.com/api/v2/languages")
    }
    
    func testAPIInitializationWithOrganization() {
        api = LanguagesAPI(organizationName: testOrganization)
        
        XCTAssert(api.baseURL == "https://\(testOrganization).crowdin.com/api/v2/")
        XCTAssert(api.apiPath == "languages")
        XCTAssert(api.organizationName == testOrganization)
        XCTAssert(api.fullPath == "https://\(testOrganization).crowdin.com/api/v2/languages")
    }
    
    func testGetLanguages() {
        let expectation = XCTestExpectation(description: "Wait for callback")
        
        session.data = """
        {
          "data": [
            {
              "data": {
                "id": "ach",
                "name": "Acholi",
                "editorCode": "ach",
                "twoLettersCode": "ach",
                "threeLettersCode": "ach",
                "locale": "ach-UG",
                "androidCode": "ach-rUG",
                "osxCode": "ach.lproj",
                "osxLocale": "ach",
                "pluralCategoryNames": [
                  "one",
                  "other"
                ],
                "pluralRules": "(n > 1)",
                "pluralExamples": [
                  "0, 1",
                  "2-999; 1.2, 2.07..."
                ],
                "textDirection": "ltr",
                "dialectOf": null
              }
            },
            {
              "data": {
                "id": "aa",
                "name": "Afar",
                "editorCode": "aa",
                "twoLettersCode": "aa",
                "threeLettersCode": "aar",
                "locale": "aa-ER",
                "androidCode": "aa-rER",
                "osxCode": "aa.lproj",
                "osxLocale": "aa",
                "pluralCategoryNames": [
                  "one",
                  "other"
                ],
                "pluralRules": "(n != 1)",
                "pluralExamples": [
                  "1",
                  "0, 2-999; 1.2, 2.07..."
                ],
                "textDirection": "ltr",
                "dialectOf": null
              }
            }
          ],
          "pagination": {
            "offset": 0,
            "limit": 2
          }
        }
        """.data(using: .utf8)
        api = LanguagesAPI(organizationName: testOrganization, session: session)
        
        var result: LanguagesResponse? = nil
        api.getLanguages(limit: 2, offset: 0) { (response, _) in
            result = response
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: defaultTimeoutForExpectation)
        
        XCTAssertNotNil(result)
        if let result = result {
            XCTAssert(result.data.count == 2)
            XCTAssertNotNil(result.data.first)
            
            if let language = result.data.first {
                XCTAssert(language.data.id == "ach")
                XCTAssert(language.data.name == "Acholi")
                
                XCTAssert(language.data.editorCode == "ach")
                XCTAssert(language.data.twoLettersCode == "ach")
                XCTAssert(language.data.locale == "ach-UG")
                XCTAssert(language.data.androidCode == "ach-rUG")
                XCTAssert(language.data.osxCode == "ach.lproj")
                XCTAssert(language.data.osxLocale == "ach")
                XCTAssert(language.data.pluralCategoryNames.count == 2)
                XCTAssert(language.data.pluralRules == "(n > 1)")
                XCTAssert(language.data.pluralExamples.count == 2)
                XCTAssert(language.data.textDirection == .ltr)
                XCTAssertNil(language.data.dialectOf)
            }
            
            XCTAssert(result.pagination.limit == 2)
            XCTAssert(result.pagination.offset == 0)
        }
    }
}
