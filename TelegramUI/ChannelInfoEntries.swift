import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import Display

private enum ChannelInfoSection: ItemListSectionId {
    case info
    case sharedMediaAndNotifications
    case members
    case reportOrLeave
}

enum ChannelInfoEntry: PeerInfoEntry {
    case info(peer: Peer?, cachedData: CachedPeerData?)
    case about(text: String)
    case userName(value: String)
    case sharedMedia
    case notifications(settings: PeerNotificationSettings?)
    case report
    case member(index: Int, peerId: PeerId, peer: Peer?, presence: PeerPresence?, memberStatus: GroupInfoMemberStatus)
    case leave
    
    var section: ItemListSectionId {
        switch self {
            case .info, .about, .userName:
                return ChannelInfoSection.info.rawValue
            case .sharedMedia, .notifications:
                return ChannelInfoSection.sharedMediaAndNotifications.rawValue
            case .member:
                return ChannelInfoSection.members.rawValue
            case .report, .leave:
                return ChannelInfoSection.reportOrLeave.rawValue
        }
    }
    
    var stableId: PeerInfoEntryStableId {
        return IntPeerInfoEntryStableId(value: self.sortIndex)
    }
    
    func isEqual(to: PeerInfoEntry) -> Bool {
        guard let entry = to as? ChannelInfoEntry else {
            return false
        }
        switch self {
            case let .info(lhsPeer, lhsCachedData):
                switch entry {
                    case let .info(rhsPeer, rhsCachedData):
                        if let lhsPeer = lhsPeer, let rhsPeer = rhsPeer {
                            if !lhsPeer.isEqual(rhsPeer) {
                                return false
                            }
                        } else if (lhsPeer == nil) != (rhsPeer != nil) {
                            return false
                        }
                        if let lhsCachedData = lhsCachedData, let rhsCachedData = rhsCachedData {
                            if !lhsCachedData.isEqual(to: rhsCachedData) {
                                return false
                            }
                        } else if (lhsCachedData != nil) != (rhsCachedData != nil) {
                            return false
                        }
                        return true
                    default:
                        return false
                }
            case let .about(lhsText):
                switch entry {
                    case let .about(lhsText):
                        return true
                    default:
                        return false
                }
            case let .userName(value):
                switch entry {
                    case .userName(value):
                        return true
                    default:
                        return false
                }
            case .sharedMedia:
                switch entry {
                    case .sharedMedia:
                        return true
                    default:
                        return false
                }
            case let .notifications(lhsSettings):
                switch entry {
                    case let .notifications(rhsSettings):
                        if let lhsSettings = lhsSettings, let rhsSettings = rhsSettings {
                            return lhsSettings.isEqual(to: rhsSettings)
                        } else if (lhsSettings != nil) != (rhsSettings != nil) {
                            return false
                        }
                        return true
                    default:
                        return false
                }
            case let .member(lhsIndex, lhsPeerId, lhsPeer, lhsPresence, lhsMemberStatus):
                if case let .member(rhsIndex, rhsPeerId, rhsPeer, rhsPresence, rhsMemberStatus) = entry, lhsIndex == rhsIndex && lhsPeerId == rhsPeerId, lhsMemberStatus == rhsMemberStatus {
                    if let lhsPeer = lhsPeer, let rhsPeer = rhsPeer {
                        if !lhsPeer.isEqual(rhsPeer) {
                            return false
                        }
                    } else if (lhsPeer == nil) != (rhsPeer != nil) {
                        return false
                    }
                    if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                        if !lhsPresence.isEqual(to: rhsPresence) {
                            return false
                        }
                    } else if (lhsPresence == nil) != (rhsPresence != nil) {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case .report:
                switch entry {
                    case .report:
                        return true
                    default:
                        return false
                }
            case .leave:
                switch entry {
                    case .leave:
                        return true
                    default:
                        return false
                }
        }
    }
    
    private var sortIndex: Int {
        switch self {
            case .info:
                return 0
            case .about:
                return 1
            case .userName:
                return 2
            case .sharedMedia:
                return 3
            case .notifications:
                return 4
            case let .member(index, _, _, _, _):
                return 100 + index
            case .report:
                return 1001
            case .leave:
                return 1002
        }
    }
    
    func isOrderedBefore(_ entry: PeerInfoEntry) -> Bool {
        guard let entry = entry as? ChannelInfoEntry else {
            return false
        }
        return self.sortIndex < entry.sortIndex
    }
    
    func item(account: Account, interaction: PeerInfoControllerInteraction) -> ListViewItem {
        switch self {
            case let .info(peer, cachedData):
                return ItemListAvatarAndNameInfoItem(account: account, peer: peer, cachedData: cachedData, state: ItemListAvatarAndNameInfoItemState(editingName: nil, updatingName: nil), sectionId: self.section, style: .plain, editingNameUpdated: { editingName in
                    
                })
            case let .about(text):
                return ItemListTextWithLabelItem(label: "about", text: text, multiline: true, sectionId: self.section)
            case let .userName(value):
                return ItemListTextWithLabelItem(label: "share link", text: "https://telegram.me/\(value)", multiline: false, sectionId: self.section)
                return ItemListActionItem(title: "Start Secret Chat", kind: .generic, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    
                })
            case .sharedMedia:
                return ItemListDisclosureItem(title: "Shared Media", label: "", sectionId: self.section, style: .plain, action: {
                    interaction.openSharedMedia()
                })
            case let .notifications(settings):
                let label: String
                if let settings = settings as? TelegramPeerNotificationSettings, case .muted = settings.muteState {
                    label = "Disabled"
                } else {
                    label = "Enabled"
                }
                return ItemListDisclosureItem(title: "Notifications", label: label, sectionId: self.section, style: .plain, action: {
                    interaction.changeNotificationMuteSettings()
                })
            case let .member(_, peerId, peer, presence, memberStatus):
                let label: String?
                switch memberStatus {
                    case .admin:
                        label = "admin"
                    case .member:
                        label = nil
                }
                return ItemListPeerItem(account: account, peer: peer, presence: presence, label: label, sectionId: self.section, action: {
                    if let peer = peer {
                        interaction.openPeerInfo(peer.id)
                    }
                })
            case .report:
                return ItemListActionItem(title: "Report", kind: .generic, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    
                })
            case .leave:
                return ItemListActionItem(title: "Leave Channel", kind: .destructive, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    
                })
        }
    }
}

func channelBroadcastInfoEntries(view: PeerView) -> PeerInfoEntries {
    var entries: [PeerInfoEntry] = []
    entries.append(ChannelInfoEntry.info(peer: view.peers[view.peerId], cachedData: view.cachedData))
    if let cachedChannelData = view.cachedData as? CachedChannelData {
        if let about = cachedChannelData.about, !about.isEmpty {
            entries.append(ChannelInfoEntry.about(text: about))
        }
    }
    if let channel = view.peers[view.peerId] as? TelegramChannel {
        if let username = channel.username, !username.isEmpty {
            entries.append(ChannelInfoEntry.userName(value: username))
        }
        entries.append(ChannelInfoEntry.sharedMedia)
        entries.append(ChannelInfoEntry.notifications(settings: view.notificationSettings))
        entries.append(ChannelInfoEntry.report)
        if channel.participationStatus == .member {
            entries.append(ChannelInfoEntry.leave)
        }
    }
    return PeerInfoEntries(entries: entries, leftNavigationButton: nil, rightNavigationButton: nil)
}
