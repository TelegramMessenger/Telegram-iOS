import AccountContext
import NGApiClient
import NGData
import NGUtils
import Postbox
import SwiftSignalKit
import TelegramCore
import Foundation

private let thresholdGroupMemebrsCount: Int = 1000

private let apiClient = createNicegramApiClient(auth: nil, trackMobileIdentifier: false)
private let throttlingService = ChatStatsThrottlingService()

public func isShareChannelsInfoEnabled() -> Bool {
    return NGSettings.shareChannelsInfo
}

public func setShareChannelsInfo(enabled: Bool) {
    NGSettings.shareChannelsInfo = enabled
}

public func shareChannelInfo(peerId: PeerId, context: AccountContext) {
    if !isShareChannelsInfoEnabled() {
        return
    }
    
    if throttlingService.shouldSkipShare(peerId: peerId) {
        return
    }
    
    _ = (context.account.viewTracker.peerView(peerId, updateData: true)
    |> take(1))
    .start(next: { peerView in
        if let peer = peerView.peers[peerView.peerId] {
            shareChannelInfo(peer: peer, cachedData: peerView.cachedData, context: context)
        }
    })
}

private func shareChannelInfo(peer: Peer, cachedData: CachedPeerData?, context: AccountContext) {
    if isGroup(peer: peer) {
        let participantsCount = extractParticipantsCount(peer: peer, cachedData: cachedData)
        if participantsCount < thresholdGroupMemebrsCount {
            return
        }
    } else if !isChannel(peer: peer) {
        return
    }
    
    let avatarImageSignal = fetchAvatarImage(peer: peer, context: context)
    let inviteLinksSignal = context.engine.peers.direct_peerExportedInvitations(peerId: peer.id, revoked: false)
    let interlocutorLanguageSignal = wrapped_detectInterlocutorLanguage(forChatWith: peer.id, context: context)
    
    _ = (combineLatest(avatarImageSignal, inviteLinksSignal, interlocutorLanguageSignal)
    |> take(1)).start(next: { avatarImageData, inviteLinks, interlocutorLanguage in
        shareChannelInfo(peer: peer, cachedData: cachedData, avatarImageData: avatarImageData, inviteLinks: inviteLinks, interlocutorLanguage: interlocutorLanguage)
    })
}

private func shareChannelInfo(peer: Peer, cachedData: CachedPeerData?, avatarImageData: Data?, inviteLinks: ExportedInvitations?, interlocutorLanguage: String?) {
    let id = extractPeerId(peer: peer)
    
    let type: ProfileTypeDTO
    let payload: ProfilePayload
    switch EnginePeer(peer) {
    case let .legacyGroup(group):
        type = .group
        payload = extractPayload(
            group: group,
            cachedData: cachedData as? CachedGroupData,
            lastMessageLanguageCode: interlocutorLanguage
        )
    case let .channel(channel):
        switch channel.info {
        case .broadcast:
            type = .channel
        case .group:
            type = .group
        }
        payload = extractPayload(
            channel: channel,
            cachedData: cachedData as? CachedChannelData,
            lastMessageLanguageCode: interlocutorLanguage
        )
    default:
        return
    }
    
    let inviteLinks = inviteLinks?.list?.compactMap({ InviteLinkDTO(exportedInvitation: $0) }) ?? []
    
    let profileImageBase64 = avatarImageData?.base64EncodedString()
    
    let body = ProfileInfoBody(id: id, type: type, inviteLinks: inviteLinks, icon: profileImageBase64, payload: AnyProfilePayload(wrapped: payload))
    
    throttlingService.markAsShared(peerId: peer.id)
    apiClient.send(.post(path: "telegram/chat", body: body), completion: nil)
}

private func extractPayload(group: TelegramGroup, cachedData: CachedGroupData?, lastMessageLanguageCode: String?) -> ProfilePayload {
    let isDeactivated = group.flags.contains(.deactivated)
    let title = group.title
    let participantsCount = group.participantCount
    let date = group.creationDate
    let migratedTo = group.migrationReference?.peerId.id._internalGetInt64Value()
    let photo = extractProfileImageDTO(peer: group)
    let about = cachedData?.about
    
    return GroupPayload(deactivated: isDeactivated, title: title, participantsCount: participantsCount, date: date, migratedTo: migratedTo, photo: photo, lastMessageLang: lastMessageLanguageCode, about: about)
}

private func extractPayload(channel: TelegramChannel, cachedData: CachedChannelData?, lastMessageLanguageCode: String?) -> ProfilePayload {
    let isVerified = channel.isVerified
    let isScam = channel.isScam
    let hasGeo = channel.flags.contains(.hasGeo)
    let isFake = channel.isFake
    let isGigagroup = channel.flags.contains(.isGigagroup)
    let title = channel.title
    let username = channel.username
    let date = channel.creationDate
    let restrictions = channel.restrictionInfo?.rules.map({ RestrictionRuleDTO(restrictionRule: $0) }) ?? []
    let participantsCount = cachedData?.participantsSummary.memberCount
    let photo = extractProfileImageDTO(peer: channel)
    let about = cachedData?.about
    let geoLocation = cachedData?.peerGeoLocation.flatMap({ GeoLocationDTO(peerGeoLocation: $0) })
    
    return ChannelPayload(verified: isVerified, scam: isScam, hasGeo: hasGeo, fake: isFake, gigagroup: isGigagroup, title: title, username: username, date: date, restrictions: restrictions, participantsCount: participantsCount, photo: photo, lastMessageLang: lastMessageLanguageCode, about: about, geoLocation: geoLocation)
}

private func extractProfileImageDTO(peer: Peer) -> ProfileImageDTO? {
    guard let imageRepresentation = peer.profileImageRepresentations.first else {
        return nil
    }
    guard let resource = imageRepresentation.resource as? CloudPeerPhotoSizeMediaResource else {
        return nil
    }
    return ProfileImageDTO(cloudPeerPhotoSizeMediaResource: resource)
}

private func isChannel(peer: Peer) -> Bool {
    if case let .channel(channel) = EnginePeer(peer),
       case .broadcast = channel.info {
        return true
    } else {
        return false
    }
}

public func isGroup(peer: Peer) -> Bool {
    switch EnginePeer(peer) {
    case let .channel(channel):
        switch channel.info {
        case .group:
            return true
        case .broadcast:
            return false
        }
    case .legacyGroup:
        return true
    default:
        return false
    }
}

func extractParticipantsCount(peer: Peer, cachedData: CachedPeerData?) -> Int {
    switch EnginePeer(peer) {
    case .user:
        return 2
    case .channel:
        let channelData = cachedData as? CachedChannelData
        return Int(channelData?.participantsSummary.memberCount ?? 0)
    case let .legacyGroup(group):
        return group.participantCount
    case .secretChat:
        return 0
    }
}
