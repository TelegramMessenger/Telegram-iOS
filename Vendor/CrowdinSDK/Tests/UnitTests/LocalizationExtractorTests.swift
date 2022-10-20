//
//  LocalizationExtractorTests.swift
//  TestsTests
//
//  Created by Serhii Londar on 20.10.2019.
//  Copyright © 2019 Serhii Londar. All rights reserved.
//

import XCTest
@testable import CrowdinSDK

class LocalizationExtractorTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testInBundleLocalizations() {
        XCTAssert(LocalizationExtractor.allLocalizations.count == 3)
        XCTAssert(LocalizationExtractor.allLocalizations.contains("em"))
        XCTAssert(LocalizationExtractor.allLocalizations.contains("de"))
        XCTAssert(LocalizationExtractor.allLocalizations.contains("uk"))
    }

    func testExtractDefaultLocalization() {
        let extractor = LocalizationExtractor()
        
        XCTAssert(extractor.localization == "en")
        XCTAssert(!extractor.isEmpty)
        XCTAssert(!extractor.allKeys.isEmpty)
        XCTAssert(!extractor.allValues.isEmpty)
        
    }
    
    func testExtractLocalizationJSON() {
        XCTAssert(!LocalizationExtractor.extractLocalizationJSON().isEmpty)
    }
    
    func testExtractLocalizationJSONtoPath() {
        let file = DocumentsFolder.root.file(with: "LocalizationJSON.json")
        
        LocalizationExtractor.extractLocalizationJSONFile(to: file!.path)
        
        let dictFile = DictionaryFile(path: file!.path)
        
        XCTAssertNotNil(file)
        XCTAssert(file!.isCreated)
        
        let extractedLocalization = dictFile.file
        
        XCTAssertNotNil(extractedLocalization)
        XCTAssert(!extractedLocalization!.isEmpty)
    }

}
