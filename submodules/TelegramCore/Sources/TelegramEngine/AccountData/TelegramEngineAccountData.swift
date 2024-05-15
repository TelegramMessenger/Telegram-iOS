import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

public extension TelegramEngine {
    final class AccountData {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func acceptTermsOfService(id: String) -> Signal<Void, NoError> {
		    return _internal_acceptTermsOfService(account: self.account, id: id)
		}

        public func requestChangeAccountPhoneNumberVerification(apiId: Int32, apiHash: String, phoneNumber: String, pushNotificationConfiguration: AuthorizationCodePushNotificationConfiguration?, firebaseSecretStream: Signal<[String: String], NoError>) -> Signal<ChangeAccountPhoneNumberData, RequestChangeAccountPhoneNumberVerificationError> {
            return _internal_requestChangeAccountPhoneNumberVerification(account: self.account, apiId: apiId, apiHash: apiHash, phoneNumber: phoneNumber, pushNotificationConfiguration: pushNotificationConfiguration, firebaseSecretStream: firebaseSecretStream)
        }

        public func requestNextChangeAccountPhoneNumberVerification(phoneNumber: String, phoneCodeHash: String, apiId: Int32, apiHash: String, firebaseSecretStream: Signal<[String: String], NoError>) -> Signal<ChangeAccountPhoneNumberData, RequestChangeAccountPhoneNumberVerificationError> {
            return _internal_requestNextChangeAccountPhoneNumberVerification(account: self.account, phoneNumber: phoneNumber, phoneCodeHash: phoneCodeHash, apiId: apiId, apiHash: apiHash, firebaseSecretStream: firebaseSecretStream)
        }

        public func requestChangeAccountPhoneNumber(phoneNumber: String, phoneCodeHash: String, phoneCode: String) -> Signal<Void, ChangeAccountPhoneNumberError> {
            return _internal_requestChangeAccountPhoneNumber(account: self.account, phoneNumber: phoneNumber, phoneCodeHash: phoneCodeHash, phoneCode: phoneCode)
        }

        public func updateAccountPeerName(firstName: String, lastName: String) -> Signal<Void, NoError> {
            return _internal_updateAccountPeerName(account: self.account, firstName: firstName, lastName: lastName)
        }

        public func updateAbout(about: String?) -> Signal<Void, UpdateAboutError> {
            return _internal_updateAbout(account: self.account, about: about)
        }
        
        public func updateBirthday(birthday: TelegramBirthday?) -> Signal<Never, UpdateBirthdayError> {
            return _internal_updateBirthday(account: self.account, birthday: birthday)
        }
        
        public func observeAvailableColorOptions(scope: PeerColorsScope) -> Signal<EngineAvailableColorOptions, NoError> {
            return _internal_observeAvailableColorOptions(postbox: self.account.postbox, scope: scope)
        }
        
        public func updateNameColorAndEmoji(nameColor: PeerNameColor, backgroundEmojiId: Int64?, profileColor: PeerNameColor?, profileBackgroundEmojiId: Int64?) -> Signal<Void, UpdateNameColorAndEmojiError> {
            return _internal_updateNameColorAndEmoji(account: self.account, nameColor: nameColor, backgroundEmojiId: backgroundEmojiId, profileColor: profileColor, profileBackgroundEmojiId: profileBackgroundEmojiId)
        }

        public func unregisterNotificationToken(token: Data, type: NotificationTokenType, otherAccountUserIds: [PeerId.Id]) -> Signal<Never, NoError> {
            return _internal_unregisterNotificationToken(account: self.account, token: token, type: type, otherAccountUserIds: otherAccountUserIds)
        }

        public func registerNotificationToken(token: Data, type: NotificationTokenType, sandbox: Bool, otherAccountUserIds: [PeerId.Id], excludeMutedChats: Bool) -> Signal<Bool, NoError> {
            return _internal_registerNotificationToken(account: self.account, token: token, type: type, sandbox: sandbox, otherAccountUserIds: otherAccountUserIds, excludeMutedChats: excludeMutedChats)
        }

        public func updateAccountPhoto(resource: MediaResource?, videoResource: MediaResource?, videoStartTimestamp: Double?, markup: UploadPeerPhotoMarkup?, mapResourceToAvatarSizes: @escaping (MediaResource, [TelegramMediaImageRepresentation]) -> Signal<[Int: Data], NoError>) -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> {
            return _internal_updateAccountPhoto(account: self.account, resource: resource, videoResource: videoResource, videoStartTimestamp: videoStartTimestamp, markup: markup, fallback: false, mapResourceToAvatarSizes: mapResourceToAvatarSizes)
        }

        public func updatePeerPhotoExisting(reference: TelegramMediaImageReference) -> Signal<TelegramMediaImage?, NoError> {
            return _internal_updatePeerPhotoExisting(network: self.account.network, reference: reference)
        }

        public func removeAccountPhoto(reference: TelegramMediaImageReference?) -> Signal<Void, NoError> {
            return _internal_removeAccountPhoto(account: self.account, reference: reference, fallback: false)
        }
        
        public func updateFallbackPhoto(resource: MediaResource?, videoResource: MediaResource?, videoStartTimestamp: Double?, markup: UploadPeerPhotoMarkup?, mapResourceToAvatarSizes: @escaping (MediaResource, [TelegramMediaImageRepresentation]) -> Signal<[Int: Data], NoError>) -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> {
            return _internal_updateAccountPhoto(account: self.account, resource: resource, videoResource: videoResource, videoStartTimestamp: videoStartTimestamp, markup: markup, fallback: true, mapResourceToAvatarSizes: mapResourceToAvatarSizes)
        }

        public func removeFallbackPhoto(reference: TelegramMediaImageReference?) -> Signal<Void, NoError> {
            return _internal_removeAccountPhoto(account: self.account, reference: reference, fallback: true)
        }
        
        public func setEmojiStatus(file: TelegramMediaFile?, expirationDate: Int32?) -> Signal<Never, NoError> {
            let peerId = self.account.peerId
            
            let remoteApply = self.account.network.request(Api.functions.account.updateEmojiStatus(emojiStatus: file.flatMap({ file in
                if let expirationDate = expirationDate {
                    return Api.EmojiStatus.emojiStatusUntil(documentId: file.fileId.id, until: expirationDate)
                } else {
                    return Api.EmojiStatus.emojiStatus(documentId: file.fileId.id)
                }
            }) ?? Api.EmojiStatus.emojiStatusEmpty))
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .single(.boolFalse)
            }
            |> ignoreValues
            
            return self.account.postbox.transaction { transaction -> Void in
                if let file = file {
                    transaction.storeMediaIfNotPresent(media: file)
                    
                    if let entry = CodableEntry(RecentMediaItem(file)) {
                        let itemEntry = OrderedItemListEntry(id: RecentMediaItemId(file.fileId).rawValue, contents: entry)
                        transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentStatusEmoji, item: itemEntry, removeTailIfCountExceeds: 32)
                    }
                }
                
                if let peer = transaction.getPeer(peerId) as? TelegramUser {
                    updatePeersCustom(transaction: transaction, peers: [peer.withUpdatedEmojiStatus(file.flatMap({ PeerEmojiStatus(fileId: $0.fileId.id, expirationDate: expirationDate) }))], update: { _, updated in
                        updated
                    })
                }
            }
            |> ignoreValues
            |> then(remoteApply)
        }
        
        public func updateAccountBusinessHours(businessHours: TelegramBusinessHours?) -> Signal<Never, NoError> {
            let peerId = self.account.peerId
            
            var flags: Int32 = 0
            if businessHours != nil {
                flags |= 1 << 0
            }
            let remoteApply: Signal<Never, NoError> = self.account.network.request(Api.functions.account.updateBusinessWorkHours(flags: flags, businessWorkHours: businessHours?.apiBusinessHours))
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .single(.boolFalse)
            }
            |> ignoreValues
            
            return self.account.postbox.transaction { transaction -> Void in
                transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                    let current = current as? CachedUserData ?? CachedUserData()
                    return current.withUpdatedBusinessHours(businessHours)
                })
            }
            |> ignoreValues
            |> then(remoteApply)
        }
        
        public func updateAccountBusinessLocation(businessLocation: TelegramBusinessLocation?) -> Signal<Never, NoError> {
            let peerId = self.account.peerId
            
            var flags: Int32 = 0
            
            var inputGeoPoint: Api.InputGeoPoint?
            var inputAddress: String?
            if let businessLocation {
                flags |= 1 << 0
                inputAddress = businessLocation.address
                
                inputGeoPoint = businessLocation.coordinates?.apiInputGeoPoint
                if inputGeoPoint != nil {
                    flags |= 1 << 1
                }
            }
            
            let remoteApply: Signal<Never, NoError> = self.account.network.request(Api.functions.account.updateBusinessLocation(flags: flags, geoPoint: inputGeoPoint, address: inputAddress))
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .single(.boolFalse)
            }
            |> ignoreValues
            
            return self.account.postbox.transaction { transaction -> Void in
                transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                    let current = current as? CachedUserData ?? CachedUserData()
                    return current.withUpdatedBusinessLocation(businessLocation)
                })
            }
            |> ignoreValues
            |> then(remoteApply)
        }
        
        public func shortcutMessageList(onlyRemote: Bool) -> Signal<ShortcutMessageList, NoError> {
            return _internal_shortcutMessageList(account: self.account, onlyRemote: onlyRemote)
        }

        public func keepShortcutMessageListUpdated() -> Signal<Never, NoError> {
            return _internal_keepShortcutMessagesUpdated(account: self.account)
        }
        
        public func editMessageShortcut(id: Int32, shortcut: String) {
            let _ = _internal_editMessageShortcut(account: self.account, id: id, shortcut: shortcut).startStandalone()
        }
        
        public func deleteMessageShortcuts(ids: [Int32]) {
            let _ = _internal_deleteMessageShortcuts(account: self.account, ids: ids).startStandalone()
        }
        
        public func reorderMessageShortcuts(ids: [Int32], completion: @escaping () -> Void) {
            let _ = _internal_reorderMessageShortcuts(account: self.account, ids: ids, localCompletion: completion).startStandalone()
        }
        
        public func sendMessageShortcut(peerId: EnginePeer.Id, id: Int32) {
            let _ = _internal_sendMessageShortcut(account: self.account, peerId: peerId, id: id).startStandalone()
        }
        
        public func cachedTimeZoneList() -> Signal<TimeZoneList?, NoError> {
            return _internal_cachedTimeZoneList(account: self.account)
        }

        public func keepCachedTimeZoneListUpdated() -> Signal<Never, NoError> {
            return _internal_keepCachedTimeZoneListUpdated(account: self.account)
        }
        
        public func updateBusinessGreetingMessage(greetingMessage: TelegramBusinessGreetingMessage?) -> Signal<Never, NoError> {
            return _internal_updateBusinessGreetingMessage(account: self.account, greetingMessage: greetingMessage)
        }
        
        public func updateBusinessAwayMessage(awayMessage: TelegramBusinessAwayMessage?) -> Signal<Never, NoError> {
            return _internal_updateBusinessAwayMessage(account: self.account, awayMessage: awayMessage)
        }
        
        public func setAccountConnectedBot(bot: TelegramAccountConnectedBot?) -> Signal<Never, NoError> {
            return _internal_setAccountConnectedBot(account: self.account, bot: bot)
        }
        
        public func updateBusinessIntro(intro: TelegramBusinessIntro?) -> Signal<Never, NoError> {
            return _internal_updateBusinessIntro(account: self.account, intro: intro)
        }
        
        public func createBusinessChatLink(message: String, entities: [MessageTextEntity], title: String?) -> Signal<TelegramBusinessChatLinks.Link, AddBusinessChatLinkError> {
            return _internal_createBusinessChatLink(account: self.account, message: message, entities: entities, title: title)
        }
        
        public func editBusinessChatLink(url: String, message: String, entities: [MessageTextEntity], title: String?) -> Signal<TelegramBusinessChatLinks.Link, AddBusinessChatLinkError> {
            return _internal_editBusinessChatLink(account: self.account, url: url, message: message, entities: entities, title: title)
        }
        
        public func deleteBusinessChatLink(url: String) -> Signal<Never, NoError> {
            return _internal_deleteBusinessChatLink(account: self.account, url: url)
        }
        
        public func refreshBusinessChatLinks() -> Signal<Never, NoError> {
            return _internal_refreshBusinessChatLinks(postbox: self.account.postbox, network: self.account.network, accountPeerId: self.account.peerId)
        }
        
        public func updatePersonalChannel(personalChannel: TelegramPersonalChannel?) -> Signal<Never, NoError> {
            return _internal_updatePersonalChannel(account: self.account, personalChannel: personalChannel)
        }
        
        public func updateAdMessagesEnabled(enabled: Bool) -> Signal<Never, AdMessagesEnableError> {
            return _internal_updateAdMessagesEnabled(account: self.account, enabled: enabled)
        }
    }
}
