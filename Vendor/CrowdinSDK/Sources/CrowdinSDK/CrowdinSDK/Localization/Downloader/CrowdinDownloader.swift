//
//  CrowdinDownloader.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 6/5/19.
//

import Foundation

typealias CrowdinDownloaderCompletion = (_ strings: [String: String]?, _ plurals: [AnyHashable: Any]?, _ errors: [Error]?) -> Void

protocol CrowdinDownloaderProtocol {
    func download(with hash: String, for localization: String, completion: @escaping CrowdinDownloaderCompletion)
}
