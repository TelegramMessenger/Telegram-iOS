//
//  CrowdinDownloadOperation.swift
//  BaseAPI
//
//  Created by Serhii Londar on 05.12.2019.
//

import Foundation

protocol CrowdinDownloadOperationProtocol {
    var filePath: String { get }
    var contentDeliveryAPI: CrowdinContentDeliveryAPI { get }
}

class CrowdinDownloadOperation: AsyncOperation, CrowdinDownloadOperationProtocol {    
    var filePath: String
    var contentDeliveryAPI: CrowdinContentDeliveryAPI
    
    init(filePath: String, contentDeliveryAPI: CrowdinContentDeliveryAPI) {
        self.filePath = filePath
        self.contentDeliveryAPI = contentDeliveryAPI
    }
    
    override func main() {
        fatalError("Please use child classes: CrowdinStringsDownloadOperation, CrowdinPluralsDownloadOperation")
    }
}
