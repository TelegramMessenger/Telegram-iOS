//
//  DownloadOperation.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 3/24/19.
//

import Foundation

class CrowdinStringsMappingDownloadOperation: CrowdinDownloadOperation {
    var completion: (([String: String]?, Error?) -> Void)? = nil
    var strings: [String: String]?
    var error: Error?
    
    init(filePath: String, contentDeliveryAPI: CrowdinContentDeliveryAPI, completion: (([String: String]?, Error?) -> Void)?) {
        super.init(filePath: filePath, contentDeliveryAPI: contentDeliveryAPI)
        self.completion = completion
    }
    
    override init(filePath: String, contentDeliveryAPI: CrowdinContentDeliveryAPI) {
        super.init(filePath: filePath, contentDeliveryAPI: contentDeliveryAPI)
    }
    
    override func main() {
        contentDeliveryAPI.getStringsMapping(filePath: filePath, etag: nil, timestamp: nil) { [weak self] (strings, error) in
            guard let self = self else { return }
            self.strings = strings
            self.error = error
            self.completion?(self.strings, self.error)
            self.finish(with: error != nil)
        }
    }
}
