//
//  DocumentsFolder.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 3/10/19.
//

import Foundation

class DocumentsFolder: Folder {
    static let root = DocumentsFolder()
    
    static let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    
    init(_ path: String) {
        super.init(path: path)
    }
    
    init() {
        super.init(path: DocumentsFolder.documentsPath)
    }
    
    init(name: String) {
        super.init(path: DocumentsFolder.documentsPath + String.pathDelimiter + name)
    }
}
