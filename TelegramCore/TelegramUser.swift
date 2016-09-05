import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public final class TelegramUser: Peer {
    public let id: PeerId
    public let accessHash: Int64?
    public let firstName: String?
    public let lastName: String?
    public let username: String?
    public let phone: String?
    public let photo: [TelegramMediaImageRepresentation]
    
    public var name: String {
        if let firstName = self.firstName {
            if let lastName = self.lastName {
                return "\(firstName) \(lastName)"
            } else {
                return firstName
            }
        } else if let lastName = self.lastName {
            return lastName
        } else {
            return ""
        }
    }
    
    public var indexName: PeerIndexNameRepresentation {
        return .personName(first: self.firstName ?? "", last: self.lastName ?? "")
    }
    
    public init(id: PeerId, accessHash: Int64?, firstName: String?, lastName: String?, username: String?, phone: String?, photo: [TelegramMediaImageRepresentation]) {
        self.id = id
        self.accessHash = accessHash
        self.firstName = firstName
        self.lastName = lastName
        self.username = username
        self.phone = phone
        self.photo = photo
    }
    
    public init(decoder: Decoder) {
        self.id = PeerId(decoder.decodeInt64ForKey("i"))
        
        let accessHash: Int64 = decoder.decodeInt64ForKey("ah")
        if accessHash != 0 {
            self.accessHash = accessHash
        } else {
            self.accessHash = nil
        }
        
        self.firstName = decoder.decodeStringForKey("fn")
        self.lastName = decoder.decodeStringForKey("ln")
        
        self.username = decoder.decodeStringForKey("un")
        self.phone = decoder.decodeStringForKey("p")
        
        self.photo = decoder.decodeObjectArrayForKey("ph")
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt64(self.id.toInt64(), forKey: "i")
        
        if let accessHash = self.accessHash {
            encoder.encodeInt64(accessHash, forKey: "ah")
        }
        
        if let firstName = self.firstName {
            encoder.encodeString(firstName, forKey: "fn")
        }
        if let lastName = self.lastName {
            encoder.encodeString(lastName, forKey: "ln")
        }
        
        if let username = self.username {
            encoder.encodeString(username, forKey: "un")
        }
        if let phone = self.phone {
            encoder.encodeString(phone, forKey: "p")
        }
        
        encoder.encodeObjectArray(self.photo, forKey: "ph")
    }
    
    public func isEqual(_ other: Peer) -> Bool {
        if let other = other as? TelegramUser {
            if self.id != other.id {
                return false
            }
            if self.accessHash != other.accessHash {
                return false
            }
            if self.firstName != other.firstName {
                return false
            }
            if self.lastName != other.lastName {
                return false
            }
            if self.phone != other.phone {
                return false
            }
            if self.photo.count != other.photo.count {
                return false
            }
            for i in 0 ..< self.photo.count {
                if self.photo[i] != other.photo[i] {
                    return false
                }
            }
            
            return true
        } else {
            return false
        }
    }
}

public extension TelegramUser {
    public convenience init(user: Api.User) {
        switch user {
            case let .user(_, id, accessHash, firstName, lastName, username, phone, photo, _, _, _, _):
                var telegramPhoto: [TelegramMediaImageRepresentation] = []
                if let photo = photo {
                    switch photo {
                        case let .userProfilePhoto(_, photoSmall, photoBig):
                            if let smallLocation = telegramMediaLocationFromApiLocation(photoSmall), let largeLocation = telegramMediaLocationFromApiLocation(photoBig) {
                                telegramPhoto.append(TelegramMediaImageRepresentation(dimensions: CGSize(width: 80.0, height: 80.0), location: smallLocation, size: nil))
                                telegramPhoto.append(TelegramMediaImageRepresentation(dimensions: CGSize(width: 640.0, height: 640.0), location: largeLocation, size: nil))
                            }
                        case .userProfilePhotoEmpty:
                            break
                    }
                }
                self.init(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: id), accessHash: accessHash, firstName: firstName, lastName: lastName, username: username, phone: phone, photo: telegramPhoto)
            case let .userEmpty(id):
                self.init(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: id), accessHash: nil, firstName: nil, lastName: nil, username: nil, phone: nil, photo: [])
        }
    }
    
    public static func merge(_ lhs: TelegramUser?, rhs: Api.User) -> TelegramUser? {
        switch rhs {
            case let .user(_, _, accessHash, _, _, username, _, photo, _, _, _, _):
                if let _ = accessHash {
                    return TelegramUser(user: rhs)
                } else {
                    var telegramPhoto: [TelegramMediaImageRepresentation] = []
                    if let photo = photo {
                        switch photo {
                            case let .userProfilePhoto(_, photoSmall, photoBig):
                                if let smallLocation = telegramMediaLocationFromApiLocation(photoSmall), let largeLocation = telegramMediaLocationFromApiLocation(photoBig) {
                                    telegramPhoto.append(TelegramMediaImageRepresentation(dimensions: CGSize(width: 80.0, height: 80.0), location: smallLocation, size: nil))
                                    telegramPhoto.append(TelegramMediaImageRepresentation(dimensions: CGSize(width: 640.0, height: 640.0), location: largeLocation, size: nil))
                                }
                            case .userProfilePhotoEmpty:
                                break
                        }
                    }
                    if let lhs = lhs {
                        return TelegramUser(id: lhs.id, accessHash: lhs.accessHash, firstName: lhs.firstName, lastName: lhs.lastName, username: username, phone: lhs.phone, photo: telegramPhoto)
                    } else {
                        return TelegramUser(user: rhs)
                    }
                }
            case .userEmpty:
                return TelegramUser(user: rhs)
        }
    }
}
