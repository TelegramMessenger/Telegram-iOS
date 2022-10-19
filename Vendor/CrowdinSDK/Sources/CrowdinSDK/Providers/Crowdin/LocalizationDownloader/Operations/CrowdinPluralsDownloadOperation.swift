//
//  CrowdinPluralsDownloadOperation.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 05.12.2019.
//

import Foundation

class CrowdinPluralsDownloadOperation: CrowdinDownloadOperation {
    var completion: (([AnyHashable: Any]?, Error?) -> Void)? = nil
    var timestamp: TimeInterval?
    var eTagStorage: ETagStorage
    
    init(filePath: String, localization: String, timestamp: TimeInterval?, contentDeliveryAPI: CrowdinContentDeliveryAPI, completion: (([AnyHashable: Any]?, Error?) -> Void)?) {
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
        contentDeliveryAPI.getPlurals(filePath: self.filePath, etag: etag, timestamp: nil,completion: { [weak self] (plurals, etag, error) in
            guard let self = self else { return }
            self.eTagStorage.etags[self.filePath] = etag
            self.completion?(plurals, error)
            self.finish(with: error != nil)
        })
    }
}
