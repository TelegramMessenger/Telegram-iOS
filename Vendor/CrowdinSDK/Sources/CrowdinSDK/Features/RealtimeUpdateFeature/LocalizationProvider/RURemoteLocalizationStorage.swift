//
//  RealtimeUpdatesLocalizationProvider.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 08.02.2020.
//

import Foundation

class RURemoteLocalizationStorage: RemoteLocalizationStorageProtocol {
    var name: String = "RURemoteLocalizationProvider"

    func deintegrate() { }
    
    var localization: String
    var localizations: [String]
    var hash: String
    var fileDownloader: RUFilesDownloader
    
    init(localization: String, hash: String, projectId: String, organizationName: String?) {
        self.localization = localization
        self.hash = hash
        self.fileDownloader = RUFilesDownloader(projectId: projectId, laguageResolver: ManifestManager.shared(for: hash), organizationName: organizationName)
        self.localizations = ManifestManager.shared(for: hash).iOSLanguages
    }
    
    func prepare(with completion: (() -> Void)) {
        completion()
    }
    
    func fetchData(completion: @escaping LocalizationStorageCompletion, errorHandler: LocalizationStorageError?) {
        self.fileDownloader.download(with: hash, for: localization) { (strings, plurals, errors) in
            if let errors = errors { errors.forEach { errorHandler?($0) } }
            completion([self.localization], self.localization, strings, plurals)
        }
    }
}
