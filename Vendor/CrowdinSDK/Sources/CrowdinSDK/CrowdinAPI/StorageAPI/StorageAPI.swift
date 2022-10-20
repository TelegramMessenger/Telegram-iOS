//
//  StorageAPI.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 5/8/19.
//

import Foundation
import BaseAPI

class StorageAPI: CrowdinAPI {
    fileprivate enum StorageRequestHeaderFields: String {
        case CrowdinAPIFileName = "Crowdin-API-FileName"
    }
    
    override var apiPath: String {
        return "storages"
    }
    
    func uploadNewFile(data: Data, fileName: String? = nil, completion: @escaping (StorageUploadResponse?, Error?) -> Void) {
        let apiFileName = fileName ?? String(Date().timeIntervalSince1970)
        let apiFileNameWithExtension = apiFileName.hasSuffix(".png") ? apiFileName : apiFileName + ".png"
        let headers = [RequestHeaderFields.contentType.rawValue: "image/png",
                       StorageRequestHeaderFields.CrowdinAPIFileName.rawValue: apiFileNameWithExtension]
        self.cw_post(url: fullPath, headers: headers, body: data, completion: completion)
    }
}
