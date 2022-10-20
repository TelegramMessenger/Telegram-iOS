//
//  CrowdinPluralsMappingDownloadOperation.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 05.12.2019.
//

import Foundation

class CrowdinPluralsMappingDownloadOperation: CrowdinDownloadOperation {
    var completion: (([AnyHashable: Any]?, Error?) -> Void)? = nil
    var plurals: [AnyHashable: Any]?
    var error: Error?
    
    init(filePath: String, contentDeliveryAPI: CrowdinContentDeliveryAPI, completion: (([AnyHashable: Any]?, Error?) -> Void)?) {
        super.init(filePath: filePath, contentDeliveryAPI: contentDeliveryAPI)
        self.completion = completion
    }
    
    override init(filePath: String, contentDeliveryAPI: CrowdinContentDeliveryAPI) {
        super.init(filePath: filePath, contentDeliveryAPI: contentDeliveryAPI)
    }
    
    override func main() {
        self.contentDeliveryAPI.getPluralsMapping(filePath: self.filePath, etag: nil, timestamp: nil) { [weak self] (plurals, error) in
            guard let self = self else { return }
            self.plurals = plurals
            self.error = error
            self.completion?(self.plurals, self.error)
            self.finish(with: error != nil)
        }
    }
}
