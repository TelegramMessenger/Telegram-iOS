//
//  ProjectsAPI.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 09.02.2020.
//

import Foundation
import BaseAPI

class ProjectsAPI: CrowdinAPI {
    override var apiPath: String {
        return "projects"
    }
    
    func getFilesList(projectId: String, limit: Int? = nil, offset: Int? = nil, completion: @escaping (_ response: ProjectsFilesListResponse?, _ error: Error?) -> Void) {
        var parameters = [String: String]()
        if let limit = limit {
            parameters["limit"] = String(limit)
        }
        if let offset = offset {
            parameters["offset"] = String(offset)
        }
        let url = "\(fullPath)/\(projectId)/files"
        self.cw_get(url: url, parameters: parameters, completion: completion)
    }
    
    func getFilesListSync(projectId: String, limit: Int? = nil, offset: Int? = nil) -> (response: ProjectsFilesListResponse?, error: Error?) {
        var parameters = [String: String]()
        if let limit = limit {
            parameters["limit"] = String(limit)
        }
        if let offset = offset {
            parameters["offset"] = String(offset)
        }
        let url = "\(fullPath)/\(projectId)/files"
        return self.cw_getSync(url: url, parameters: parameters)
    }
    
    func downloadFile(projectId: String, fileId: String, completion: @escaping (ProjectsDownloadFileResponse?, Error?) -> Void) {
        let url = "\(fullPath)/\(projectId)/files/\(fileId)/download"
        self.cw_get(url: url, completion: completion)
    }
    
    func downloadFileData(url: String, completion:  @escaping (Data?, Error?) -> Void) {
        let decodedUrl = url.removingPercentEncoding ?? url
        self.get(url: decodedUrl) { (data, _, error) in
            completion(data, error)
        }
    }
    func buildProjectFileTranslation(projectId: String, fileId: String, targetLanguageId: String, completion: @escaping (ProjectsDownloadFileResponse?, Error?) -> Void) {
        let headers = [RequestHeaderFields.contentType.rawValue: "application/json"]
        let body = try? JSONEncoder().encode(["targetLanguageId": targetLanguageId])
        let url = "\(fullPath)/\(projectId)/translations/builds/files/\(fileId)"
        self.cw_post(url: url, parameters: nil, headers: headers, body: body, completion: completion)
    }
}
