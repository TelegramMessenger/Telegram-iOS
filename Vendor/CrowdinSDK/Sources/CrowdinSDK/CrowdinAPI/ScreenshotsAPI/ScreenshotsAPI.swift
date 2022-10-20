//
//  ScreenshotsAPI.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 5/9/19.
//

import Foundation
import CoreGraphics
import BaseAPI

class ScreenshotsAPI: CrowdinAPI {
    override var apiPath: String {
        return "projects"
    }
    
    func baseUrl(with projectId: Int) -> String{
        return "\(fullPath)/\(projectId)/screenshots"
    }

    func createScreenshot(projectId: Int, storageId: Int, name: String, autoTag: Bool = false, completion: @escaping (CreateScreenshotResponse?, Error?) -> Void) {
        let request = CreateScreenshotRequest(storageId: storageId, name: name, autoTag: autoTag)
        let requestData = try? JSONEncoder().encode(request)
        let url = baseUrl(with: projectId)
        let headers = [RequestHeaderFields.contentType.rawValue: "application/json"]
        self.cw_post(url: url, headers: headers, body: requestData, completion: completion)
    }
    
    func createScreenshotTags(projectId: Int, screenshotId: Int, frames: [(id: Int, rect: CGRect)], completion: @escaping (CreateScreenshotTagResponse?, Error?) -> Void) {
        var elements = [CreateScreenshotTagRequestElement]()
        for frame in frames {
            let key = frame.id
            let value = frame.rect
            elements.append(CreateScreenshotTagRequestElement(stringId: key, position: CreateScreenshotTagPosition(x: Int(value.origin.x), y: Int(value.origin.y), width: Int(value.size.width), height: Int(value.size.height))))
        }
        let request = elements
        let requestData = try? JSONEncoder().encode(request)
        let url = baseUrl(with: projectId) + "/\(screenshotId)/tags"
        let headers = [RequestHeaderFields.contentType.rawValue: "application/json"]
        self.cw_post(url: url, headers: headers, body: requestData, completion: completion)
    }
}
