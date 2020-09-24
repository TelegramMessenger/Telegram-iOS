// //
// //  NicegramSettings.swift
// //  NGData
// //
// //  Created by Sergey on 20.09.2020.
// //

// import Foundation
// import Postbox
// import SwiftSignalKit
// import SyncCore

// public struct NicegramSettings: Equatable, PreferencesEntry {
//     public var premium: Bool
    
//     public static var defaultSettings: NicegramSettings {
//         return NicegramSettings(
//             premium: false
//         )
//     }
    
//     public init(
//         premium: Bool
//     ) {
//         self.premium = premium
//     }
    
//     public init(decoder: PostboxDecoder) {
//         self.premium = decoder.decodeInt32ForKey("premium", orElse: 0) != 0
//     }
    
//     public func encode(_ encoder: PostboxEncoder) {
//         encoder.encodeInt32(self.premium ? 1 : 0, forKey: "premium")
//     }
    
//     public func isEqual(to: PreferencesEntry) -> Bool {
//         if let to = to as? NicegramSettings {
//             return self == to
//         } else {
//             return false
//         }
//     }
// }

// public func updateNicegramSettingsInteractively(accountManager: AccountManager, _ f: @escaping (NicegramSettings) -> NicegramSettings) -> Signal<Void, NoError> {
//     return accountManager.transaction { transaction -> Void in
//         transaction.updateSharedData(applicationSpecificSharedDataKey(100), { entry in
//             let currentSettings: NicegramSettings
//             if let entry = entry as? NicegramSettings {
//                 currentSettings = entry
//             } else {
//                 currentSettings = .defaultSettings
//             }
//             return f(currentSettings)
//         })
//     }
// }
