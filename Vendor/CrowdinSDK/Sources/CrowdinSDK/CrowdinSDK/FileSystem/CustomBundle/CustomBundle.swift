//
//  CustomBundle.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 2/12/19.
//

import Foundation

protocol BundleProtocol {
    var bundle: Bundle { get }
}

protocol FolderBundleProtocol: BundleProtocol {
    var folder: FolderProtocol { get }
}

class FolderBundle: FolderBundleProtocol {
    var bundle: Bundle
    var folder: FolderProtocol
    
    init(folder: FolderProtocol) {
        self.folder = folder
        // swiftlint:disable force_unwrapping
        self.bundle = Bundle(path: folder.path)!
    }
    
    init(path: String) {
        self.folder = Folder(path: path)
        try? self.folder.create()
        // swiftlint:disable force_unwrapping
        self.bundle = Bundle(path: folder.path)!
    }
}

protocol FileBundleProtocol: BundleProtocol {
    var file: File { get }
}

class FileBundle: FolderBundle, FileBundleProtocol {
    var file: File
    
    init(path: String, fileName: String) {
        let folder = Folder(path: path)
        self.file = File(path: folder.path + String.pathDelimiter + fileName)
        super.init(path: path)
    }
}

protocol DictionaryBundleProtocol: BundleProtocol {
	var dictionary: Dictionary<AnyHashable, Any> { get }
    var file: DictionaryFile { get }
    func remove()
}

class DictionaryBundle: FolderBundle, DictionaryBundleProtocol {
	var dictionary: Dictionary<AnyHashable, Any>
    var file: DictionaryFile
    
    init(path: String, fileName: String, dictionary: [AnyHashable: Any]) {
        self.dictionary = dictionary
        let folder = Folder(path: path)
        self.file = DictionaryFile(path: folder.path + String.pathDelimiter + fileName)
        self.file.file = self.dictionary
        try? self.file.save()
        super.init(path: path)
    }
    
    func remove() {
		try? self.folder.remove()
        try? self.file.remove()
    }
}
