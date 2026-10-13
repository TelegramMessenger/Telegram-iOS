import TelegramApiObjC
public extension Api {
    enum CdnPublicKey: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_cdnPublicKey {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case cdnPublicKey(Cons_cdnPublicKey)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .cdnPublicKey(Cons_cdnPublicKey(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .cdnPublicKey(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.CdnPublicKey] {
            return tlObjectsAt(object, offset).map { Api.CdnPublicKey(tlObject: $0) }
        }

    }
}
public extension Api.CdnPublicKey.Cons_cdnPublicKey {
    @_alwaysEmitIntoClient var dcId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var publicKey: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(dcId: Int32, publicKey: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1339))
        tlStore(_tlObject, 24, dcId)
        tlStoreReference(_tlObject, 32, publicKey as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum ChannelAdminLogEvent: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_channelAdminLogEvent {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case channelAdminLogEvent(Cons_channelAdminLogEvent)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .channelAdminLogEvent(Cons_channelAdminLogEvent(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .channelAdminLogEvent(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ChannelAdminLogEvent] {
            return tlObjectsAt(object, offset).map { Api.ChannelAdminLogEvent(tlObject: $0) }
        }

    }
}
public extension Api.ChannelAdminLogEvent.Cons_channelAdminLogEvent {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var action: Api.ChannelAdminLogEventAction {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChannelAdminLogEventAction(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(id: Int64, date: Int32, userId: Int64, action: Api.ChannelAdminLogEventAction) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(214))
        tlStore(_tlObject, 32, id)
        tlStore(_tlObject, 24, date)
        tlStore(_tlObject, 40, userId)
        tlStoreReference(_tlObject, 48, action.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum ChannelAdminLogEventAction: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_channelAdminLogEventActionChangeAbout {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionChangeAvailableReactions {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionChangeEmojiStatus {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionChangeEmojiStickerSet {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionChangeHistoryTTL {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionChangeLinkedChat {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionChangeLocation {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionChangePeerColor {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionChangePhoto {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionChangeProfilePeerColor {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionChangeStickerSet {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionChangeTitle {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionChangeUsername {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionChangeUsernames {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionChangeWallpaper {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionCreateTopic {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionDefaultBannedRights {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionDeleteMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionDeleteTopic {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionDiscardGroupCall {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionEditMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionEditTopic {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionExportedInviteDelete {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionExportedInviteEdit {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionExportedInviteRevoke {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionParticipantEditRank {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionParticipantInvite {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionParticipantJoinByInvite {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionParticipantJoinByRequest {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionParticipantMute {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionParticipantSubExtend {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionParticipantToggleAdmin {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionParticipantToggleBan {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionParticipantUnmute {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionParticipantVolume {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionPinTopic {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionSendMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionStartGroupCall {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionStopPoll {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionToggleAntiSpam {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionToggleAutotranslation {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionToggleForum {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionToggleGroupCallSetting {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionToggleInvites {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionToggleNoForwards {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionTogglePreHistoryHidden {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionToggleSignatureProfiles {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionToggleSignatures {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionToggleSlowMode {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelAdminLogEventActionUpdatePinned {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case channelAdminLogEventActionChangeAbout(Cons_channelAdminLogEventActionChangeAbout)
        case channelAdminLogEventActionChangeAvailableReactions(Cons_channelAdminLogEventActionChangeAvailableReactions)
        case channelAdminLogEventActionChangeEmojiStatus(Cons_channelAdminLogEventActionChangeEmojiStatus)
        case channelAdminLogEventActionChangeEmojiStickerSet(Cons_channelAdminLogEventActionChangeEmojiStickerSet)
        case channelAdminLogEventActionChangeHistoryTTL(Cons_channelAdminLogEventActionChangeHistoryTTL)
        case channelAdminLogEventActionChangeLinkedChat(Cons_channelAdminLogEventActionChangeLinkedChat)
        case channelAdminLogEventActionChangeLocation(Cons_channelAdminLogEventActionChangeLocation)
        case channelAdminLogEventActionChangePeerColor(Cons_channelAdminLogEventActionChangePeerColor)
        case channelAdminLogEventActionChangePhoto(Cons_channelAdminLogEventActionChangePhoto)
        case channelAdminLogEventActionChangeProfilePeerColor(Cons_channelAdminLogEventActionChangeProfilePeerColor)
        case channelAdminLogEventActionChangeStickerSet(Cons_channelAdminLogEventActionChangeStickerSet)
        case channelAdminLogEventActionChangeTitle(Cons_channelAdminLogEventActionChangeTitle)
        case channelAdminLogEventActionChangeUsername(Cons_channelAdminLogEventActionChangeUsername)
        case channelAdminLogEventActionChangeUsernames(Cons_channelAdminLogEventActionChangeUsernames)
        case channelAdminLogEventActionChangeWallpaper(Cons_channelAdminLogEventActionChangeWallpaper)
        case channelAdminLogEventActionCreateTopic(Cons_channelAdminLogEventActionCreateTopic)
        case channelAdminLogEventActionDefaultBannedRights(Cons_channelAdminLogEventActionDefaultBannedRights)
        case channelAdminLogEventActionDeleteMessage(Cons_channelAdminLogEventActionDeleteMessage)
        case channelAdminLogEventActionDeleteTopic(Cons_channelAdminLogEventActionDeleteTopic)
        case channelAdminLogEventActionDiscardGroupCall(Cons_channelAdminLogEventActionDiscardGroupCall)
        case channelAdminLogEventActionEditMessage(Cons_channelAdminLogEventActionEditMessage)
        case channelAdminLogEventActionEditTopic(Cons_channelAdminLogEventActionEditTopic)
        case channelAdminLogEventActionExportedInviteDelete(Cons_channelAdminLogEventActionExportedInviteDelete)
        case channelAdminLogEventActionExportedInviteEdit(Cons_channelAdminLogEventActionExportedInviteEdit)
        case channelAdminLogEventActionExportedInviteRevoke(Cons_channelAdminLogEventActionExportedInviteRevoke)
        case channelAdminLogEventActionParticipantEditRank(Cons_channelAdminLogEventActionParticipantEditRank)
        case channelAdminLogEventActionParticipantInvite(Cons_channelAdminLogEventActionParticipantInvite)
        case channelAdminLogEventActionParticipantJoin
        case channelAdminLogEventActionParticipantJoinByInvite(Cons_channelAdminLogEventActionParticipantJoinByInvite)
        case channelAdminLogEventActionParticipantJoinByRequest(Cons_channelAdminLogEventActionParticipantJoinByRequest)
        case channelAdminLogEventActionParticipantLeave
        case channelAdminLogEventActionParticipantMute(Cons_channelAdminLogEventActionParticipantMute)
        case channelAdminLogEventActionParticipantSubExtend(Cons_channelAdminLogEventActionParticipantSubExtend)
        case channelAdminLogEventActionParticipantToggleAdmin(Cons_channelAdminLogEventActionParticipantToggleAdmin)
        case channelAdminLogEventActionParticipantToggleBan(Cons_channelAdminLogEventActionParticipantToggleBan)
        case channelAdminLogEventActionParticipantUnmute(Cons_channelAdminLogEventActionParticipantUnmute)
        case channelAdminLogEventActionParticipantVolume(Cons_channelAdminLogEventActionParticipantVolume)
        case channelAdminLogEventActionPinTopic(Cons_channelAdminLogEventActionPinTopic)
        case channelAdminLogEventActionSendMessage(Cons_channelAdminLogEventActionSendMessage)
        case channelAdminLogEventActionStartGroupCall(Cons_channelAdminLogEventActionStartGroupCall)
        case channelAdminLogEventActionStopPoll(Cons_channelAdminLogEventActionStopPoll)
        case channelAdminLogEventActionToggleAntiSpam(Cons_channelAdminLogEventActionToggleAntiSpam)
        case channelAdminLogEventActionToggleAutotranslation(Cons_channelAdminLogEventActionToggleAutotranslation)
        case channelAdminLogEventActionToggleForum(Cons_channelAdminLogEventActionToggleForum)
        case channelAdminLogEventActionToggleGroupCallSetting(Cons_channelAdminLogEventActionToggleGroupCallSetting)
        case channelAdminLogEventActionToggleInvites(Cons_channelAdminLogEventActionToggleInvites)
        case channelAdminLogEventActionToggleNoForwards(Cons_channelAdminLogEventActionToggleNoForwards)
        case channelAdminLogEventActionTogglePreHistoryHidden(Cons_channelAdminLogEventActionTogglePreHistoryHidden)
        case channelAdminLogEventActionToggleSignatureProfiles(Cons_channelAdminLogEventActionToggleSignatureProfiles)
        case channelAdminLogEventActionToggleSignatures(Cons_channelAdminLogEventActionToggleSignatures)
        case channelAdminLogEventActionToggleSlowMode(Cons_channelAdminLogEventActionToggleSlowMode)
        case channelAdminLogEventActionUpdatePinned(Cons_channelAdminLogEventActionUpdatePinned)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .channelAdminLogEventActionChangeAbout(Cons_channelAdminLogEventActionChangeAbout(tlObject: object))
            case 1:
                self = .channelAdminLogEventActionChangeAvailableReactions(Cons_channelAdminLogEventActionChangeAvailableReactions(tlObject: object))
            case 2:
                self = .channelAdminLogEventActionChangeEmojiStatus(Cons_channelAdminLogEventActionChangeEmojiStatus(tlObject: object))
            case 3:
                self = .channelAdminLogEventActionChangeEmojiStickerSet(Cons_channelAdminLogEventActionChangeEmojiStickerSet(tlObject: object))
            case 4:
                self = .channelAdminLogEventActionChangeHistoryTTL(Cons_channelAdminLogEventActionChangeHistoryTTL(tlObject: object))
            case 5:
                self = .channelAdminLogEventActionChangeLinkedChat(Cons_channelAdminLogEventActionChangeLinkedChat(tlObject: object))
            case 6:
                self = .channelAdminLogEventActionChangeLocation(Cons_channelAdminLogEventActionChangeLocation(tlObject: object))
            case 7:
                self = .channelAdminLogEventActionChangePeerColor(Cons_channelAdminLogEventActionChangePeerColor(tlObject: object))
            case 8:
                self = .channelAdminLogEventActionChangePhoto(Cons_channelAdminLogEventActionChangePhoto(tlObject: object))
            case 9:
                self = .channelAdminLogEventActionChangeProfilePeerColor(Cons_channelAdminLogEventActionChangeProfilePeerColor(tlObject: object))
            case 10:
                self = .channelAdminLogEventActionChangeStickerSet(Cons_channelAdminLogEventActionChangeStickerSet(tlObject: object))
            case 11:
                self = .channelAdminLogEventActionChangeTitle(Cons_channelAdminLogEventActionChangeTitle(tlObject: object))
            case 12:
                self = .channelAdminLogEventActionChangeUsername(Cons_channelAdminLogEventActionChangeUsername(tlObject: object))
            case 13:
                self = .channelAdminLogEventActionChangeUsernames(Cons_channelAdminLogEventActionChangeUsernames(tlObject: object))
            case 14:
                self = .channelAdminLogEventActionChangeWallpaper(Cons_channelAdminLogEventActionChangeWallpaper(tlObject: object))
            case 15:
                self = .channelAdminLogEventActionCreateTopic(Cons_channelAdminLogEventActionCreateTopic(tlObject: object))
            case 16:
                self = .channelAdminLogEventActionDefaultBannedRights(Cons_channelAdminLogEventActionDefaultBannedRights(tlObject: object))
            case 17:
                self = .channelAdminLogEventActionDeleteMessage(Cons_channelAdminLogEventActionDeleteMessage(tlObject: object))
            case 18:
                self = .channelAdminLogEventActionDeleteTopic(Cons_channelAdminLogEventActionDeleteTopic(tlObject: object))
            case 19:
                self = .channelAdminLogEventActionDiscardGroupCall(Cons_channelAdminLogEventActionDiscardGroupCall(tlObject: object))
            case 20:
                self = .channelAdminLogEventActionEditMessage(Cons_channelAdminLogEventActionEditMessage(tlObject: object))
            case 21:
                self = .channelAdminLogEventActionEditTopic(Cons_channelAdminLogEventActionEditTopic(tlObject: object))
            case 22:
                self = .channelAdminLogEventActionExportedInviteDelete(Cons_channelAdminLogEventActionExportedInviteDelete(tlObject: object))
            case 23:
                self = .channelAdminLogEventActionExportedInviteEdit(Cons_channelAdminLogEventActionExportedInviteEdit(tlObject: object))
            case 24:
                self = .channelAdminLogEventActionExportedInviteRevoke(Cons_channelAdminLogEventActionExportedInviteRevoke(tlObject: object))
            case 25:
                self = .channelAdminLogEventActionParticipantEditRank(Cons_channelAdminLogEventActionParticipantEditRank(tlObject: object))
            case 26:
                self = .channelAdminLogEventActionParticipantInvite(Cons_channelAdminLogEventActionParticipantInvite(tlObject: object))
            case 27:
                self = .channelAdminLogEventActionParticipantJoin
            case 28:
                self = .channelAdminLogEventActionParticipantJoinByInvite(Cons_channelAdminLogEventActionParticipantJoinByInvite(tlObject: object))
            case 29:
                self = .channelAdminLogEventActionParticipantJoinByRequest(Cons_channelAdminLogEventActionParticipantJoinByRequest(tlObject: object))
            case 30:
                self = .channelAdminLogEventActionParticipantLeave
            case 31:
                self = .channelAdminLogEventActionParticipantMute(Cons_channelAdminLogEventActionParticipantMute(tlObject: object))
            case 32:
                self = .channelAdminLogEventActionParticipantSubExtend(Cons_channelAdminLogEventActionParticipantSubExtend(tlObject: object))
            case 33:
                self = .channelAdminLogEventActionParticipantToggleAdmin(Cons_channelAdminLogEventActionParticipantToggleAdmin(tlObject: object))
            case 34:
                self = .channelAdminLogEventActionParticipantToggleBan(Cons_channelAdminLogEventActionParticipantToggleBan(tlObject: object))
            case 35:
                self = .channelAdminLogEventActionParticipantUnmute(Cons_channelAdminLogEventActionParticipantUnmute(tlObject: object))
            case 36:
                self = .channelAdminLogEventActionParticipantVolume(Cons_channelAdminLogEventActionParticipantVolume(tlObject: object))
            case 37:
                self = .channelAdminLogEventActionPinTopic(Cons_channelAdminLogEventActionPinTopic(tlObject: object))
            case 38:
                self = .channelAdminLogEventActionSendMessage(Cons_channelAdminLogEventActionSendMessage(tlObject: object))
            case 39:
                self = .channelAdminLogEventActionStartGroupCall(Cons_channelAdminLogEventActionStartGroupCall(tlObject: object))
            case 40:
                self = .channelAdminLogEventActionStopPoll(Cons_channelAdminLogEventActionStopPoll(tlObject: object))
            case 41:
                self = .channelAdminLogEventActionToggleAntiSpam(Cons_channelAdminLogEventActionToggleAntiSpam(tlObject: object))
            case 42:
                self = .channelAdminLogEventActionToggleAutotranslation(Cons_channelAdminLogEventActionToggleAutotranslation(tlObject: object))
            case 43:
                self = .channelAdminLogEventActionToggleForum(Cons_channelAdminLogEventActionToggleForum(tlObject: object))
            case 44:
                self = .channelAdminLogEventActionToggleGroupCallSetting(Cons_channelAdminLogEventActionToggleGroupCallSetting(tlObject: object))
            case 45:
                self = .channelAdminLogEventActionToggleInvites(Cons_channelAdminLogEventActionToggleInvites(tlObject: object))
            case 46:
                self = .channelAdminLogEventActionToggleNoForwards(Cons_channelAdminLogEventActionToggleNoForwards(tlObject: object))
            case 47:
                self = .channelAdminLogEventActionTogglePreHistoryHidden(Cons_channelAdminLogEventActionTogglePreHistoryHidden(tlObject: object))
            case 48:
                self = .channelAdminLogEventActionToggleSignatureProfiles(Cons_channelAdminLogEventActionToggleSignatureProfiles(tlObject: object))
            case 49:
                self = .channelAdminLogEventActionToggleSignatures(Cons_channelAdminLogEventActionToggleSignatures(tlObject: object))
            case 50:
                self = .channelAdminLogEventActionToggleSlowMode(Cons_channelAdminLogEventActionToggleSlowMode(tlObject: object))
            case 51:
                self = .channelAdminLogEventActionUpdatePinned(Cons_channelAdminLogEventActionUpdatePinned(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .channelAdminLogEventActionChangeAbout(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionChangeAvailableReactions(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionChangeEmojiStatus(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionChangeEmojiStickerSet(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionChangeHistoryTTL(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionChangeLinkedChat(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionChangeLocation(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionChangePeerColor(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionChangePhoto(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionChangeProfilePeerColor(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionChangeStickerSet(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionChangeTitle(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionChangeUsername(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionChangeUsernames(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionChangeWallpaper(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionCreateTopic(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionDefaultBannedRights(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionDeleteMessage(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionDeleteTopic(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionDiscardGroupCall(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionEditMessage(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionEditTopic(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionExportedInviteDelete(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionExportedInviteEdit(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionExportedInviteRevoke(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionParticipantEditRank(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionParticipantInvite(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionParticipantJoin:
                return TLObjectSingleton(TLApiConstructorAt(155))
            case .channelAdminLogEventActionParticipantJoinByInvite(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionParticipantJoinByRequest(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionParticipantLeave:
                return TLObjectSingleton(TLApiConstructorAt(1650))
            case .channelAdminLogEventActionParticipantMute(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionParticipantSubExtend(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionParticipantToggleAdmin(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionParticipantToggleBan(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionParticipantUnmute(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionParticipantVolume(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionPinTopic(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionSendMessage(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionStartGroupCall(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionStopPoll(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionToggleAntiSpam(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionToggleAutotranslation(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionToggleForum(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionToggleGroupCallSetting(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionToggleInvites(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionToggleNoForwards(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionTogglePreHistoryHidden(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionToggleSignatureProfiles(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionToggleSignatures(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionToggleSlowMode(let _data):
                return _data.tlObject
            case .channelAdminLogEventActionUpdatePinned(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ChannelAdminLogEventAction] {
            return tlObjectsAt(object, offset).map { Api.ChannelAdminLogEventAction(tlObject: $0) }
        }

    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionChangeAbout {
    @_alwaysEmitIntoClient var prevValue: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var newValue: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(prevValue: String, newValue: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(552))
        tlStoreReference(_tlObject, 24, prevValue as NSString)
        tlStoreReference(_tlObject, 32, newValue as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionChangeAvailableReactions {
    @_alwaysEmitIntoClient var prevValue: Api.ChatReactions {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChatReactions(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var newValue: Api.ChatReactions {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChatReactions(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(prevValue: Api.ChatReactions, newValue: Api.ChatReactions) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1266))
        tlStoreReference(_tlObject, 24, prevValue.tlObject)
        tlStoreReference(_tlObject, 32, newValue.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionChangeEmojiStatus {
    @_alwaysEmitIntoClient var prevValue: Api.EmojiStatus {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.EmojiStatus(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var newValue: Api.EmojiStatus {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.EmojiStatus(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(prevValue: Api.EmojiStatus, newValue: Api.EmojiStatus) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(408))
        tlStoreReference(_tlObject, 24, prevValue.tlObject)
        tlStoreReference(_tlObject, 32, newValue.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionChangeEmojiStickerSet {
    @_alwaysEmitIntoClient var prevStickerset: Api.InputStickerSet {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputStickerSet(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var newStickerset: Api.InputStickerSet {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputStickerSet(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(prevStickerset: Api.InputStickerSet, newStickerset: Api.InputStickerSet) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(454))
        tlStoreReference(_tlObject, 24, prevStickerset.tlObject)
        tlStoreReference(_tlObject, 32, newStickerset.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionChangeHistoryTTL {
    @_alwaysEmitIntoClient var prevValue: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var newValue: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(prevValue: Int32, newValue: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(702))
        tlStore(_tlObject, 24, prevValue)
        tlStore(_tlObject, 28, newValue)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionChangeLinkedChat {
    @_alwaysEmitIntoClient var prevValue: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var newValue: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(prevValue: Int64, newValue: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(36))
        tlStore(_tlObject, 24, prevValue)
        tlStore(_tlObject, 32, newValue)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionChangeLocation {
    @_alwaysEmitIntoClient var prevValue: Api.ChannelLocation {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChannelLocation(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var newValue: Api.ChannelLocation {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChannelLocation(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(prevValue: Api.ChannelLocation, newValue: Api.ChannelLocation) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(94))
        tlStoreReference(_tlObject, 24, prevValue.tlObject)
        tlStoreReference(_tlObject, 32, newValue.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionChangePeerColor {
    @_alwaysEmitIntoClient var prevValue: Api.PeerColor {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PeerColor(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var newValue: Api.PeerColor {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PeerColor(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(prevValue: Api.PeerColor, newValue: Api.PeerColor) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(568))
        tlStoreReference(_tlObject, 24, prevValue.tlObject)
        tlStoreReference(_tlObject, 32, newValue.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionChangePhoto {
    @_alwaysEmitIntoClient var prevPhoto: Api.Photo {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Photo(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var newPhoto: Api.Photo {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Photo(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(prevPhoto: Api.Photo, newPhoto: Api.Photo) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(438))
        tlStoreReference(_tlObject, 24, prevPhoto.tlObject)
        tlStoreReference(_tlObject, 32, newPhoto.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionChangeProfilePeerColor {
    @_alwaysEmitIntoClient var prevValue: Api.PeerColor {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PeerColor(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var newValue: Api.PeerColor {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PeerColor(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(prevValue: Api.PeerColor, newValue: Api.PeerColor) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(606))
        tlStoreReference(_tlObject, 24, prevValue.tlObject)
        tlStoreReference(_tlObject, 32, newValue.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionChangeStickerSet {
    @_alwaysEmitIntoClient var prevStickerset: Api.InputStickerSet {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputStickerSet(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var newStickerset: Api.InputStickerSet {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputStickerSet(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(prevStickerset: Api.InputStickerSet, newStickerset: Api.InputStickerSet) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1157))
        tlStoreReference(_tlObject, 24, prevStickerset.tlObject)
        tlStoreReference(_tlObject, 32, newStickerset.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionChangeTitle {
    @_alwaysEmitIntoClient var prevValue: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var newValue: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(prevValue: String, newValue: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1522))
        tlStoreReference(_tlObject, 24, prevValue as NSString)
        tlStoreReference(_tlObject, 32, newValue as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionChangeUsername {
    @_alwaysEmitIntoClient var prevValue: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var newValue: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(prevValue: String, newValue: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(680))
        tlStoreReference(_tlObject, 24, prevValue as NSString)
        tlStoreReference(_tlObject, 32, newValue as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionChangeUsernames {
    @_alwaysEmitIntoClient var prevValue: [String] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringsAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var newValue: [String] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringsAt(self.tlObject, 32) } }
    }
    init(prevValue: [String], newValue: [String]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1592))
        tlStoreReference(_tlObject, 24, prevValue as NSArray)
        tlStoreReference(_tlObject, 32, newValue as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionChangeWallpaper {
    @_alwaysEmitIntoClient var prevValue: Api.WallPaper {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.WallPaper(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var newValue: Api.WallPaper {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.WallPaper(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(prevValue: Api.WallPaper, newValue: Api.WallPaper) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(315))
        tlStoreReference(_tlObject, 24, prevValue.tlObject)
        tlStoreReference(_tlObject, 32, newValue.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionCreateTopic {
    @_alwaysEmitIntoClient var topic: Api.ForumTopic {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ForumTopic(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(topic: Api.ForumTopic) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(576))
        tlStoreReference(_tlObject, 24, topic.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionDefaultBannedRights {
    @_alwaysEmitIntoClient var prevBannedRights: Api.ChatBannedRights {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChatBannedRights(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var newBannedRights: Api.ChatBannedRights {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChatBannedRights(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(prevBannedRights: Api.ChatBannedRights, newBannedRights: Api.ChatBannedRights) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(287))
        tlStoreReference(_tlObject, 24, prevBannedRights.tlObject)
        tlStoreReference(_tlObject, 32, newBannedRights.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionDeleteMessage {
    @_alwaysEmitIntoClient var message: Api.Message {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Message(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(message: Api.Message) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(433))
        tlStoreReference(_tlObject, 24, message.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionDeleteTopic {
    @_alwaysEmitIntoClient var topic: Api.ForumTopic {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ForumTopic(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(topic: Api.ForumTopic) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1136))
        tlStoreReference(_tlObject, 24, topic.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionDiscardGroupCall {
    @_alwaysEmitIntoClient var call: Api.InputGroupCall {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputGroupCall(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(call: Api.InputGroupCall) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1442))
        tlStoreReference(_tlObject, 24, call.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionEditMessage {
    @_alwaysEmitIntoClient var prevMessage: Api.Message {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Message(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var newMessage: Api.Message {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Message(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(prevMessage: Api.Message, newMessage: Api.Message) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(717))
        tlStoreReference(_tlObject, 24, prevMessage.tlObject)
        tlStoreReference(_tlObject, 32, newMessage.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionEditTopic {
    @_alwaysEmitIntoClient var prevTopic: Api.ForumTopic {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ForumTopic(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var newTopic: Api.ForumTopic {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ForumTopic(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(prevTopic: Api.ForumTopic, newTopic: Api.ForumTopic) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1593))
        tlStoreReference(_tlObject, 24, prevTopic.tlObject)
        tlStoreReference(_tlObject, 32, newTopic.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionExportedInviteDelete {
    @_alwaysEmitIntoClient var invite: Api.ExportedChatInvite {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ExportedChatInvite(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(invite: Api.ExportedChatInvite) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(587))
        tlStoreReference(_tlObject, 24, invite.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionExportedInviteEdit {
    @_alwaysEmitIntoClient var prevInvite: Api.ExportedChatInvite {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ExportedChatInvite(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var newInvite: Api.ExportedChatInvite {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ExportedChatInvite(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(prevInvite: Api.ExportedChatInvite, newInvite: Api.ExportedChatInvite) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1536))
        tlStoreReference(_tlObject, 24, prevInvite.tlObject)
        tlStoreReference(_tlObject, 32, newInvite.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionExportedInviteRevoke {
    @_alwaysEmitIntoClient var invite: Api.ExportedChatInvite {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ExportedChatInvite(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(invite: Api.ExportedChatInvite) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(420))
        tlStoreReference(_tlObject, 24, invite.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionParticipantEditRank {
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var prevRank: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var newRank: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    init(userId: Int64, prevRank: String, newRank: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(574))
        tlStore(_tlObject, 24, userId)
        tlStoreReference(_tlObject, 32, prevRank as NSString)
        tlStoreReference(_tlObject, 40, newRank as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionParticipantInvite {
    @_alwaysEmitIntoClient var participant: Api.ChannelParticipant {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChannelParticipant(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(participant: Api.ChannelParticipant) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1493))
        tlStoreReference(_tlObject, 24, participant.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionParticipantJoinByInvite {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var invite: Api.ExportedChatInvite {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ExportedChatInvite(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(flags: Int32, invite: Api.ExportedChatInvite) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1702))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, invite.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionParticipantJoinByRequest {
    @_alwaysEmitIntoClient var invite: Api.ExportedChatInvite {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ExportedChatInvite(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var approvedBy: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(invite: Api.ExportedChatInvite, approvedBy: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1144))
        tlStoreReference(_tlObject, 24, invite.tlObject)
        tlStore(_tlObject, 32, approvedBy)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionParticipantMute {
    @_alwaysEmitIntoClient var participant: Api.GroupCallParticipant {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.GroupCallParticipant(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(participant: Api.GroupCallParticipant) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1655))
        tlStoreReference(_tlObject, 24, participant.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionParticipantSubExtend {
    @_alwaysEmitIntoClient var prevParticipant: Api.ChannelParticipant {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChannelParticipant(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var newParticipant: Api.ChannelParticipant {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChannelParticipant(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(prevParticipant: Api.ChannelParticipant, newParticipant: Api.ChannelParticipant) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(644))
        tlStoreReference(_tlObject, 24, prevParticipant.tlObject)
        tlStoreReference(_tlObject, 32, newParticipant.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionParticipantToggleAdmin {
    @_alwaysEmitIntoClient var prevParticipant: Api.ChannelParticipant {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChannelParticipant(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var newParticipant: Api.ChannelParticipant {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChannelParticipant(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(prevParticipant: Api.ChannelParticipant, newParticipant: Api.ChannelParticipant) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1402))
        tlStoreReference(_tlObject, 24, prevParticipant.tlObject)
        tlStoreReference(_tlObject, 32, newParticipant.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionParticipantToggleBan {
    @_alwaysEmitIntoClient var prevParticipant: Api.ChannelParticipant {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChannelParticipant(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var newParticipant: Api.ChannelParticipant {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChannelParticipant(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(prevParticipant: Api.ChannelParticipant, newParticipant: Api.ChannelParticipant) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1521))
        tlStoreReference(_tlObject, 24, prevParticipant.tlObject)
        tlStoreReference(_tlObject, 32, newParticipant.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionParticipantUnmute {
    @_alwaysEmitIntoClient var participant: Api.GroupCallParticipant {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.GroupCallParticipant(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(participant: Api.GroupCallParticipant) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1516))
        tlStoreReference(_tlObject, 24, participant.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionParticipantVolume {
    @_alwaysEmitIntoClient var participant: Api.GroupCallParticipant {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.GroupCallParticipant(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(participant: Api.GroupCallParticipant) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(405))
        tlStoreReference(_tlObject, 24, participant.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionPinTopic {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var prevTopic: Api.ForumTopic? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.ForumTopic(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var newTopic: Api.ForumTopic? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.ForumTopic(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, prevTopic: Api.ForumTopic?, newTopic: Api.ForumTopic?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(600))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, prevTopic?.tlObject)
        tlStoreReference(_tlObject, 40, newTopic?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionSendMessage {
    @_alwaysEmitIntoClient var message: Api.Message {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Message(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(message: Api.Message) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(258))
        tlStoreReference(_tlObject, 24, message.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionStartGroupCall {
    @_alwaysEmitIntoClient var call: Api.InputGroupCall {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputGroupCall(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(call: Api.InputGroupCall) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(239))
        tlStoreReference(_tlObject, 24, call.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionStopPoll {
    @_alwaysEmitIntoClient var message: Api.Message {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Message(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(message: Api.Message) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(916))
        tlStoreReference(_tlObject, 24, message.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionToggleAntiSpam {
    @_alwaysEmitIntoClient var newValue: Api.Bool {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Bool(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(newValue: Api.Bool) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(647))
        tlStoreReference(_tlObject, 24, newValue.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionToggleAutotranslation {
    @_alwaysEmitIntoClient var newValue: Api.Bool {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Bool(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(newValue: Api.Bool) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1320))
        tlStoreReference(_tlObject, 24, newValue.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionToggleForum {
    @_alwaysEmitIntoClient var newValue: Api.Bool {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Bool(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(newValue: Api.Bool) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(19))
        tlStoreReference(_tlObject, 24, newValue.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionToggleGroupCallSetting {
    @_alwaysEmitIntoClient var joinMuted: Api.Bool {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Bool(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(joinMuted: Api.Bool) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(559))
        tlStoreReference(_tlObject, 24, joinMuted.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionToggleInvites {
    @_alwaysEmitIntoClient var newValue: Api.Bool {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Bool(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(newValue: Api.Bool) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(180))
        tlStoreReference(_tlObject, 24, newValue.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionToggleNoForwards {
    @_alwaysEmitIntoClient var newValue: Api.Bool {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Bool(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(newValue: Api.Bool) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1353))
        tlStoreReference(_tlObject, 24, newValue.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionTogglePreHistoryHidden {
    @_alwaysEmitIntoClient var newValue: Api.Bool {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Bool(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(newValue: Api.Bool) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(611))
        tlStoreReference(_tlObject, 24, newValue.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionToggleSignatureProfiles {
    @_alwaysEmitIntoClient var newValue: Api.Bool {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Bool(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(newValue: Api.Bool) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(617))
        tlStoreReference(_tlObject, 24, newValue.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionToggleSignatures {
    @_alwaysEmitIntoClient var newValue: Api.Bool {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Bool(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(newValue: Api.Bool) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(255))
        tlStoreReference(_tlObject, 24, newValue.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionToggleSlowMode {
    @_alwaysEmitIntoClient var prevValue: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var newValue: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(prevValue: Int32, newValue: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(544))
        tlStore(_tlObject, 24, prevValue)
        tlStore(_tlObject, 28, newValue)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelAdminLogEventAction.Cons_channelAdminLogEventActionUpdatePinned {
    @_alwaysEmitIntoClient var message: Api.Message {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Message(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(message: Api.Message) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1543))
        tlStoreReference(_tlObject, 24, message.tlObject)
        self.init(tlObject: _tlObject)
    }
}
