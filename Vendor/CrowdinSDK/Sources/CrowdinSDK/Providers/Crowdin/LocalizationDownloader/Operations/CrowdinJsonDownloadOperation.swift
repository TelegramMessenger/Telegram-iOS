//
//  CrowdinJsonDownloadOperation.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 05.07.2020.
//

import Foundation

typealias CrowdinJsonDownloadOperationCompletion = ([String: String]?, [AnyHashable: Any]?, Error?) -> Void

class CrowdinJsonDownloadOperation: CrowdinDownloadOperation {
    var timestamp: TimeInterval?
    var eTagStorage: ETagStorage
    var completion: CrowdinJsonDownloadOperationCompletion? = nil
    
    init(filePath: String, localization: String, timestamp: TimeInterval?, contentDeliveryAPI: CrowdinContentDeliveryAPI, completion: CrowdinJsonDownloadOperationCompletion?) {
        self.timestamp = timestamp
        self.eTagStorage = ETagStorage(localization: localization)
        super.init(filePath: filePath, contentDeliveryAPI: contentDeliveryAPI)
        self.completion = completion
    }
    
    required init(filePath: String, localization: String, timestamp: TimeInterval?, contentDeliveryAPI: CrowdinContentDeliveryAPI) {
        self.timestamp = timestamp
        self.eTagStorage = ETagStorage(localization: localization)
        super.init(filePath: filePath, contentDeliveryAPI: contentDeliveryAPI)
    }
    
    override func main() {
        let etag = eTagStorage.etags[self.filePath]
        contentDeliveryAPI.getJson(filePath: filePath, etag: etag, timestamp: timestamp) { [weak self] (strings, etag, error) in
            guard let self = self else { return }
            self.eTagStorage.etags[self.filePath] = etag
            self.completion?(strings, nil, error)
            self.finish(with: error != nil)
        }
    }
}
