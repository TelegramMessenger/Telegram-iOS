//
//  Dangerfile.swift
//  CrowdinSDK-Unit-CrowdinAPI_Tests
//
//  Created by Serhii Londar on 11.02.2020.
//

import XCTest
@testable import CrowdinSDK

class ProjectsAPITests: XCTestCase {
    var session = URLSessionMock()
    // swiftlint:disable implicitly_unwrapped_optional
    var api: ProjectsAPI!
    
    var testOrganization = "test_organization"
    var testProjectId = "352187"
    var testFileId = "6"
    let defaultTimeoutForExpectation = 2.0
    
    func testAPIInitialization() {
        api = ProjectsAPI()
        
        XCTAssert(api.baseURL == "https://crowdin.com/api/v2/")
        XCTAssert(api.apiPath == "projects")
        XCTAssertNil(api.organizationName)
        XCTAssert(api.fullPath == "https://crowdin.com/api/v2/projects")
    }
    
    func testAPIInitializationWithOrganization() {
        api = ProjectsAPI(organizationName: testOrganization)
        
        XCTAssert(api.baseURL == "https://\(testOrganization).crowdin.com/api/v2/")
        XCTAssert(api.apiPath == "projects")
        XCTAssert(api.organizationName == testOrganization)
        XCTAssert(api.fullPath == "https://\(testOrganization).crowdin.com/api/v2/projects")
    }
    
    func testGetFilesList() {
        let expectation = XCTestExpectation(description: "Wait for callback")
        
        session.data = """
        {
          "data": [
            {
              "data": {
                "id": 6,
                "projectId": 352187,
                "branchId": null,
                "directoryId": null,
                "name": "crowdin_sample_webpage.html",
                "title": null,
                "type": "html",
                "revisionId": 1,
                "status": "active",
                "priority": "normal",
                "importOptions": {
                  "contentSegmentation": true
                },
                "exportOptions": null,
                "createdAt": "2019-03-16T12:35:08+00:00",
                "updatedAt": "2019-03-16T12:35:08+00:00",
                "revision": 1
              }
            },
            {
              "data": {
                "id": 8,
                "projectId": 352187,
                "branchId": null,
                "directoryId": null,
                "name": "crowdin_sample_android.xml",
                "title": null,
                "type": "android",
                "revisionId": 1,
                "status": "active",
                "priority": "normal",
                "importOptions": null,
                "exportOptions": null,
                "createdAt": "2019-03-16T12:35:08+00:00",
                "updatedAt": "2019-03-16T12:35:09+00:00",
                "revision": 1
              }
            }
          ],
          "pagination": {
            "offset": 0,
            "limit": 25
          }
        }
        """.data(using: .utf8)
        api = ProjectsAPI(organizationName: testOrganization, session: session)
        
        var result: ProjectsFilesListResponse? = nil
        api.getFilesList(projectId: testProjectId, limit: 2, offset: 0) { (response, _) in
            result = response
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: defaultTimeoutForExpectation)
        
        XCTAssertNotNil(result)
        if let result = result {
            XCTAssert(result.data.count == 2)
            XCTAssertNotNil(result.data.first)
            
            if let file = result.data.first {
                XCTAssert(file.data.id == 6)
                XCTAssert(file.data.projectID == 352187)
                
                XCTAssertNil(file.data.branchID)
                XCTAssertNil(file.data.directoryID)
                XCTAssert(file.data.name == "crowdin_sample_webpage.html")
                XCTAssertNil(file.data.title)
                XCTAssert(file.data.type == "html")
                XCTAssert(file.data.revisionID == 1)
                XCTAssert(file.data.status == "active")
                XCTAssert(file.data.priority == "normal")
            }
            
            XCTAssert(result.pagination.offset == 0)
            XCTAssert(result.pagination.limit == 25)
        }
    }
    
    func testBuildProjectFileTranslation() {
        let expectation = XCTestExpectation(description: "Wait for callback")
        
        session.data = """
        {
            "data": {
                "url": "https://crowdin-tmp.downloads.crowdin.com/exported_files/6",
                "expireIn": "2020-02-11T10:39:18+00:00"
            }
        }
        """.data(using: .utf8)
        api = ProjectsAPI(organizationName: testOrganization, session: session)
        
        var result: ProjectsDownloadFileResponse? = nil
        api.buildProjectFileTranslation(projectId: testProjectId, fileId: testFileId, targetLanguageId: "en") { (response, _) in
            result = response
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: defaultTimeoutForExpectation)
        
        XCTAssertNotNil(result)
        XCTAssertNotNil(result?.data)
        
        if let data = result?.data {
            XCTAssert(data.url == "https://crowdin-tmp.downloads.crowdin.com/exported_files/6")
            XCTAssert(data.expireIn == "2020-02-11T10:39:18+00:00")
        }
    }
    
    func testDownloadFile() {
        let expectation = XCTestExpectation(description: "Wait for callback")
        
        session.data = """
        {
            "data": {
                "url": "https://crowdin-tmp.downloads.crowdin.com/exported_files/6",
                "expireIn": "2020-02-11T10:39:18+00:00"
            }
        }
        """.data(using: .utf8)
        api = ProjectsAPI(organizationName: testOrganization, session: session)
        
        var result: ProjectsDownloadFileResponse? = nil
        api.downloadFile(projectId: testProjectId, fileId: testFileId) { (response, _) in
            result = response
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: defaultTimeoutForExpectation)
        
        XCTAssertNotNil(result)
        XCTAssertNotNil(result?.data)
        
        if let data = result?.data {
            XCTAssert(data.url == "https://crowdin-tmp.downloads.crowdin.com/exported_files/6")
            XCTAssert(data.expireIn == "2020-02-11T10:39:18+00:00")
        }
    }
}
