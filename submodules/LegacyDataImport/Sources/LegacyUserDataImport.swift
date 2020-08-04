import Foundation
import UIKit
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox

func loadLegacyUser(database: SqliteInterface, id: Int32) -> (TelegramUser, TelegramUserPresence)? {
    var result: (TelegramUser, TelegramUserPresence)?
    database.select("SELECT uid, first_name, last_name, phone_number, access_hash, photo_small, photo_big, last_seen, username FROM users_v29 WHERE uid=\(id)", { cursor in
        let accessHash = cursor.getInt64(at: 4)
        let firstName = cursor.getString(at: 1)
        let lastName = cursor.getString(at: 2)
        let username = cursor.getString(at: 8)
        let phone = cursor.getString(at: 3)
        
        let photoSmall = cursor.getString(at: 5)
        let photoBig = cursor.getString(at: 6)
        var photo: [TelegramMediaImageRepresentation] = []
        if let resource = resourceFromLegacyImageUrl(photoSmall) {
            photo.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 80, height: 80), resource: resource, progressiveSizes: []))
        }
        if let resource = resourceFromLegacyImageUrl(photoBig) {
            photo.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 600, height: 600), resource: resource, progressiveSizes: []))
        }
        
        let user = TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: cursor.getInt32(at: 0)), accessHash: accessHash == 0 ? nil : .personal(accessHash), firstName: firstName.isEmpty ? nil : firstName, lastName: lastName.isEmpty ? nil : lastName, username: username.isEmpty ? nil : username, phone: phone.isEmpty ? nil : phone, photo: photo, botInfo: nil, restrictionInfo: nil, flags: [])
        
        let status: UserPresenceStatus
        let lastSeen = cursor.getInt32(at: 7)
        if lastSeen == -2 {
            status = .recently
        } else if lastSeen == -3 {
            status = .lastWeek
        } else if lastSeen == -4 {
            status = .lastMonth
        } else if lastSeen <= 0 {
            status = .none
        } else {
            status = .present(until: lastSeen)
        }
        
        let presence = TelegramUserPresence(status: status, lastActivity: 0)
        result = (user, presence)
        return false
    })
    return result
}
