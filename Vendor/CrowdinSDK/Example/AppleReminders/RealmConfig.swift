//
//  RealmConfig.swift
//  AppleReminders
//
//  Created by Josh R on 2/2/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import Foundation
import Realm
import RealmSwift


struct MyRealm {
    static func getConfig() -> Realm? {
        let config = Realm.Configuration(
            fileURL: URL(fileURLWithPath: RLMRealmPathForFile("default.realm"), isDirectory: false), //default file URL provided by Realm doc; need to import Realm
            inMemoryIdentifier: nil,
            syncConfiguration: nil,
            encryptionKey: nil,
            readOnly: false,
            schemaVersion: 1,
            migrationBlock: nil,
            deleteRealmIfMigrationNeeded: true,  //only set to true during development.  This will delete the default realm if there are any changes that cause a migration to fail (ie removing a class property or class entirely)
            shouldCompactOnLaunch: nil,
            objectTypes: nil
        )
        
        //Source: https://realm.io/docs/swift/latest/#realms
        
        do {
            let myRealm = try Realm(configuration: config)
            return myRealm
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
}
