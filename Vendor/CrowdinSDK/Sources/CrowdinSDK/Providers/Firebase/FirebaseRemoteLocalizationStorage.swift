//
//  FirebaseRemoteLocalizationStorage.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 3/27/19.
//

import Foundation
import FirebaseDatabase

class FirebaseRemoteLocalizationStorage: RemoteLocalizationStorage {
    var localization: String
    var path: String = "localization"
    let database: DatabaseReference = Database.database().reference()
    
    required init(localization: String) {
        self.localization = localization
    }
    
    required convenience init(localization: String, path: String) {
        self.init(localization: localization)
        self.path = path
    }
    
    func fetchData(completion: @escaping LocalizationStorageCompletion) {
        let reference = self.database.child(path)
        reference.observe(DataEventType.value) { (snapshot: DataSnapshot) in
            if var dictionary = snapshot.value as? [String: Any] {
                dictionary = dictionary.decodeFirebase()
                let localizations = [String](dictionary.keys)
                let lolcaizationDict = dictionary[self.localization] as? [String: Any] ?? [:]
                let strings = lolcaizationDict[Keys.strings.rawValue] as? [String: String] ?? [:]
                let plurals = lolcaizationDict[Keys.plurals.rawValue] as? [AnyHashable: Any] ?? [:]
                completion(localizations, strings, plurals)
            } else {
                self.uploadLocalization()
                self.fetchData(completion: completion)
            }
        }
    }
    
    func uploadLocalization() {
        let json = LocalizationExtractor.extractLocalizationJSON().encodeFirebase()
        let reference = self.database.child(path)
        reference.setValue(json)
    }
}
