import Foundation
import SwiftSignalKit
import Postbox
internal import TelegramApi

public enum SetEmojiStatusError {
    case generic
}

private final class AccountEmojiStatusRequestDependencyTag: NetworkRequestDependencyTag {
    func shouldDependOn(other: NetworkRequestDependencyTag) -> Bool {
        return other is AccountEmojiStatusRequestDependencyTag
    }
}

private func _internal_setAccountEmojiStatus(account: Account, apiEmojiStatus: Api.EmojiStatus, emojiStatus: PeerEmojiStatus?, files: [TelegramMediaFile], recentFile: TelegramMediaFile?) -> Signal<Never, SetEmojiStatusError> {
    let peerId = account.peerId
    let postbox = account.postbox
    return account.network.request(Api.functions.account.updateEmojiStatus(emojiStatus: apiEmojiStatus), tag: AccountEmojiStatusRequestDependencyTag())
    |> mapError { _ in SetEmojiStatusError.generic }
    |> then(.fail(.generic))
    |> take(1)
    |> mapToSignal { result -> Signal<Never, SetEmojiStatusError> in
        guard case .boolTrue = result else {
            return .fail(.generic)
        }
        return postbox.transaction { transaction -> Void in
            for file in files {
                transaction.storeMediaIfNotPresent(media: file)
            }
            if let recentFile, let entry = CodableEntry(RecentMediaItem(recentFile)) {
                let itemEntry = OrderedItemListEntry(id: RecentMediaItemId(recentFile.fileId).rawValue, contents: entry)
                transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentStatusEmoji, item: itemEntry, removeTailIfCountExceeds: 32)
            }
            if let peer = transaction.getPeer(peerId) as? TelegramUser {
                updatePeersCustom(transaction: transaction, peers: [peer.withUpdatedEmojiStatus(emojiStatus)], update: { _, updated in updated })
            }
        }
        |> castError(SetEmojiStatusError.self)
        |> ignoreValues
    }
}

public extension TelegramEngine {
    final class AccountData {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func acceptTermsOfService(id: String) -> Signal<Void, NoError> {
		    return _internal_acceptTermsOfService(account: self.account, id: id)
		}

        public func addAppLogEvent(time: Double = Date().timeIntervalSince1970, type: String, data: JSON = .dictionary([:])) {
            _internal_addAppLogEvent(postbox: self.account.postbox, time: time, type: type, peerId: nil, data: data)
        }

        public func addAppLogEvent(time: Double = Date().timeIntervalSince1970, type: String, peerId: EnginePeer.Id?, data: JSON = .dictionary([:])) {
            _internal_addAppLogEvent(postbox: self.account.postbox, time: time, type: type, peerId: peerId, data: data)
        }

        public func createAppLogEventContext() -> AppLogEventContext {
            return makeAppLogEventContext(postbox: self.account.postbox)
        }

        public func addAppLogEvent(time: Double = Date().timeIntervalSince1970, type: String, data: @autoclosure () -> JSON, context: AppLogEventContext) {
            AppLogEventCollection.perform(owner: self.account.postbox, identifiers: [context.identifier]) {
                let data = data()
                _internal_addAppLogEvent(postbox: self.account.postbox, time: time, type: type, data: data, context: context)
            }
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

        public func updateProfile(firstName: String?, lastName: String?, about: String?) -> Signal<Void, UpdateAccountProfileError> {
            return _internal_updateAccountProfile(account: self.account, firstName: firstName, lastName: lastName, about: about)
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
        
        public func updateNameColorAndEmoji(nameColor: UpdateNameColor, profileColor: PeerNameColor?, profileBackgroundEmojiId: Int64?) -> Signal<Void, UpdateNameColorAndEmojiError> {
            return _internal_updateNameColorAndEmoji(account: self.account, nameColor: nameColor, profileColor: profileColor, profileBackgroundEmojiId: profileBackgroundEmojiId)
        }

        public func unregisterNotificationToken(token: Data, type: NotificationTokenType, otherAccountUserIds: [PeerId.Id]) -> Signal<Never, NoError> {
            return _internal_unregisterNotificationToken(account: self.account, token: token, type: type, otherAccountUserIds: otherAccountUserIds)
        }

        public func registerNotificationToken(token: Data, type: NotificationTokenType, sandbox: Bool, otherAccountUserIds: [PeerId.Id], excludeMutedChats: Bool) -> Signal<Bool, NoError> {
            return _internal_registerNotificationToken(account: self.account, token: token, type: type, sandbox: sandbox, otherAccountUserIds: otherAccountUserIds, excludeMutedChats: excludeMutedChats)
        }

        public func updateAccountPhoto(resource: EngineMediaResource?, videoResource: EngineMediaResource?, videoStartTimestamp: Double?, markup: UploadPeerPhotoMarkup?, mapResourceToAvatarSizes: @escaping (EngineMediaResource, [TelegramMediaImageRepresentation]) -> Signal<[Int: Data], NoError>) -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> {
            return _internal_updateAccountPhoto(account: self.account, resource: resource?._asResource(), videoResource: videoResource?._asResource(), videoStartTimestamp: videoStartTimestamp, markup: markup, fallback: false, mapResourceToAvatarSizes: { rawResource, representations in
                return mapResourceToAvatarSizes(EngineMediaResource(rawResource), representations)
            })
        }

        /// `representations` and `videoRepresentations` are the photo's own sizes; the downloaded
        /// ones are reused for the photo the server returns instead of being downloaded again.
        public func updatePeerPhotoExisting(reference: TelegramMediaImageReference, representations: [TelegramMediaImageRepresentation] = [], videoRepresentations: [TelegramMediaImage.VideoRepresentation] = []) -> Signal<TelegramMediaImage?, NoError> {
            return _internal_updatePeerPhotoExisting(account: self.account, reference: reference, representations: representations, videoRepresentations: videoRepresentations)
        }

        public func removeAccountPhoto(reference: TelegramMediaImageReference?) -> Signal<Void, NoError> {
            return _internal_removeAccountPhoto(account: self.account, reference: reference, fallback: false)
        }
        
        public func updateFallbackPhoto(resource: EngineMediaResource?, videoResource: EngineMediaResource?, videoStartTimestamp: Double?, markup: UploadPeerPhotoMarkup?, mapResourceToAvatarSizes: @escaping (EngineMediaResource, [TelegramMediaImageRepresentation]) -> Signal<[Int: Data], NoError>) -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> {
            return _internal_updateAccountPhoto(account: self.account, resource: resource?._asResource(), videoResource: videoResource?._asResource(), videoStartTimestamp: videoStartTimestamp, markup: markup, fallback: true, mapResourceToAvatarSizes: { rawResource, representations in
                return mapResourceToAvatarSizes(EngineMediaResource(rawResource), representations)
            })
        }

        public func removeFallbackPhoto(reference: TelegramMediaImageReference?) -> Signal<Void, NoError> {
            return _internal_removeAccountPhoto(account: self.account, reference: reference, fallback: true)
        }
        
        public func setStarGiftStatusWithResult(starGift: StarGift.UniqueGift, expirationDate: Int32?) -> Signal<Never, SetEmojiStatusError> {
            var flags: Int32 = 0
            if let _ = expirationDate {
                flags |= (1 << 0)
            }
            var file: TelegramMediaFile?
            var patternFile: TelegramMediaFile?
            var innerColor: Int32?
            var outerColor: Int32?
            var patternColor: Int32?
            var textColor: Int32?
            for attribute in starGift.attributes {
                switch attribute {
                case let .model(_, fileValue, _, _):
                    file = fileValue
                case let .pattern(_, patternFileValue, _):
                    patternFile = patternFileValue
                case let .backdrop(_, _, innerColorValue, outerColorValue, patternColorValue, textColorValue, _):
                    innerColor = innerColorValue
                    outerColor = outerColorValue
                    patternColor = patternColorValue
                    textColor = textColorValue
                default:
                    break
                }
            }
            guard let file, let patternFile, let innerColor, let outerColor, let patternColor, let textColor else {
                return .fail(.generic)
            }
            let apiEmojiStatus = Api.EmojiStatus.inputEmojiStatusCollectible(.init(flags: flags, collectibleId: starGift.id, until: expirationDate))
            let emojiStatus = PeerEmojiStatus(content: .starGift(id: starGift.id, fileId: file.fileId.id, title: starGift.title, slug: starGift.slug, patternFileId: patternFile.fileId.id, innerColor: innerColor, outerColor: outerColor, patternColor: patternColor, textColor: textColor), expirationDate: expirationDate)
            return _internal_setAccountEmojiStatus(account: self.account, apiEmojiStatus: apiEmojiStatus, emojiStatus: emojiStatus, files: [file, patternFile], recentFile: nil)
        }

        public func setStarGiftStatus(starGift: StarGift.UniqueGift, expirationDate: Int32?) -> Signal<Never, NoError> {
            return self.setStarGiftStatusWithResult(starGift: starGift, expirationDate: expirationDate)
            |> `catch` { _ in .complete() }
        }

        public func setEmojiStatusWithResult(file: TelegramMediaFile?, expirationDate: Int32?) -> Signal<Never, SetEmojiStatusError> {
            let apiEmojiStatus = file.map { file -> Api.EmojiStatus in
                let flags: Int32 = expirationDate == nil ? 0 : 1
                return .emojiStatus(.init(flags: flags, documentId: file.fileId.id, until: expirationDate))
            } ?? .emojiStatusEmpty
            let emojiStatus = file.map { PeerEmojiStatus(content: .emoji(fileId: $0.fileId.id), expirationDate: expirationDate) }
            return _internal_setAccountEmojiStatus(account: self.account, apiEmojiStatus: apiEmojiStatus, emojiStatus: emojiStatus, files: file.map { [$0] } ?? [], recentFile: file)
        }

        public func setEmojiStatus(file: TelegramMediaFile?, expirationDate: Int32?) -> Signal<Never, NoError> {
            return self.setEmojiStatusWithResult(file: file, expirationDate: expirationDate)
            |> `catch` { _ in .complete() }
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
        
        public func confirmBotConnectionReview(botId: PeerId) -> Signal<Never, NoError> {
            return _internal_confirmBotConnectionReview(account: self.account, botId: botId)
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
