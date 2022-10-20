//
//  FileDownloadOperation.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 09.02.2020.
//

import Foundation

class FileDataDownloadOperation: AsyncOperation {
    var fileId: String
    var projectId: String
    var targetLanguageId: String
    let projectsAPI: ProjectsAPI
    var completion: ((Data?, Error?) -> Void)
    
    init(fileId: String, projectId: String, targetLanguageId: String, projectsAPI: ProjectsAPI, completion: @escaping (Data?, Error?) -> Void) {
        self.fileId = fileId
        self.projectId = projectId
        self.targetLanguageId = targetLanguageId
        self.projectsAPI = projectsAPI
        self.completion = completion
    }
    
    override func main() {
        self.projectsAPI.buildProjectFileTranslation(projectId: projectId, fileId: fileId, targetLanguageId: targetLanguageId) { [weak self] (response, error) in
            guard let self = self else { return }
            guard let url = response?.data.url else {
                self.completion(nil, error)
                self.finish(with: false)
                return
            }
            self.projectsAPI.downloadFileData(url: url, completion: { [weak self] data, error in
                guard let self = self else { return }
                self.completion(data, error)
                self.finish(with: error != nil)
            })
        }
    }
}
