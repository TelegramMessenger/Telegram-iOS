//
//  CrowdinFolder.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 3/10/19.
//

import Foundation

class CrowdinFolder: Folder {
    enum Folders: String {
        case Crowdin
        case Screenshots
    }
    
    static let shared = CrowdinFolder()
    
    let screenshotsFolder: Folder
    
    init() {
        let name = Bundle.main.bundleId + String.dot + Folders.Crowdin.rawValue
        let path = DocumentsFolder.root.path + String.pathDelimiter + name
        self.screenshotsFolder = Folder(path: path + String.pathDelimiter + Folders.Screenshots.rawValue)
        super.init(path: path)
        self.createFoldersIfNeeded()
    }
    
    func createFoldersIfNeeded() {
        self.createCrowdinFolderIfNeeded()
        self.createScreenshotsFolderIfNeeded()
    }
    
    func createCrowdinFolderIfNeeded() {
        if !self.isCreated { try? self.create() }
    }
    
    func createScreenshotsFolderIfNeeded() {
        if !screenshotsFolder.isCreated { try? screenshotsFolder.create() }
    }
}
