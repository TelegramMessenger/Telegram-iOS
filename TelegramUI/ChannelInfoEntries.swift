import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import Display

private enum ChannelInfoSection: UInt32, PeerInfoSection {
    case info
    case sharedMediaAndNotifications
    case reportOrLeave
    
    func isEqual(to: PeerInfoSection) -> Bool {
        guard let section = to as? ChannelInfoSection else {
            return false
        }
        return section == self
    }
    
    func isOrderedBefore(_ section: PeerInfoSection) -> Bool {
        guard let section = section as? ChannelInfoSection else {
            return false
        }
        return self.rawValue < section.rawValue
    }
}

enum ChannelInfoEntry: PeerInfoEntry {
    case info(peer: Peer?, cachedData: CachedPeerData?)
    case about(text: String)
    case userName(value: String)
    case sharedMedia
    case notifications(settings: PeerNotificationSettings?)
    case report
    case leave
    
    var section: PeerInfoSection {
        switch self {
            case .info, .about, .userName:
                return ChannelInfoSection.info
            case .sharedMedia, .notifications:
                return ChannelInfoSection.sharedMediaAndNotifications
            case .report, .leave:
                return ChannelInfoSection.reportOrLeave
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
                        } else if (rhsCachedData == nil) != (rhsCachedData != nil) {
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
                return 1000
            case .sharedMedia:
                return 1004
            case .notifications:
                return 1005
            case .report:
                return 1006
            case .leave:
                return 1007
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
                return PeerInfoAvatarAndNameItem(account: account, peer: peer, cachedData: cachedData, editingState: nil, sectionId: self.section.rawValue, style: .plain)
            case let .about(text):
                return PeerInfoTextWithLabelItem(label: "about", text: text, multiline: true, sectionId: self.section.rawValue)
            case let .userName(value):
                return PeerInfoTextWithLabelItem(label: "share link", text: "https://telegram.me/\(value)", multiline: false, sectionId: self.section.rawValue)
                return PeerInfoActionItem(title: "Start Secret Chat", kind: .generic, alignment: .natural, sectionId: self.section.rawValue, style: .plain, action: {
                    
                })
            case .sharedMedia:
                return PeerInfoDisclosureItem(title: "Shared Media", label: "", sectionId: self.section.rawValue, style: .plain, action: {
                    interaction.openSharedMedia()
                })
            case let .notifications(settings):
                let label: String
                if let settings = settings as? TelegramPeerNotificationSettings, case .muted = settings.muteState {
                    label = "Disabled"
                } else {
                    label = "Enabled"
                }
                return PeerInfoDisclosureItem(title: "Notifications", label: label, sectionId: self.section.rawValue, style: .plain, action: {
                    interaction.changeNotificationMuteSettings()
                })
            case .report:
                return PeerInfoActionItem(title: "Report", kind: .generic, alignment: .natural, sectionId: self.section.rawValue, style: .plain, action: {
                    
                })
            case .leave:
                return PeerInfoActionItem(title: "Leave Channel", kind: .destructive, alignment: .natural, sectionId: self.section.rawValue, style: .plain, action: {
                    
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
