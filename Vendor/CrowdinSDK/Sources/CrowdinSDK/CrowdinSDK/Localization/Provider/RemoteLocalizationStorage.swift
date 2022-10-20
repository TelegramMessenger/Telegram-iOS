//
//  RemoteLocalizationStorage.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 6/3/19.
//

import Foundation

/// Protocol for remote storage with localization files.
@objc public protocol RemoteLocalizationStorageProtocol: LocalizationStorageProtocol {
    /// Storage name.
    var name: String { get set }
    
    func prepare(with completion:  @escaping () -> Void)
}
