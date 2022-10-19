//
//  StorageUploadResponse.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 5/9/19.
//

import Foundation

struct StorageUploadResponse: Codable {
    let data: StorageUploadData
}

struct StorageUploadData: Codable {
    let id: Int
}
