import Foundation
import Postbox
import SwiftSignalKit


public struct PeerCommand: Hashable {
    public let peer: Peer
    public let command: BotCommand
    
    public static func ==(lhs: PeerCommand, rhs: PeerCommand) -> Bool {
        return lhs.peer.isEqual(rhs.peer) && lhs.command == rhs.command
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.peer.id)
        hasher.combine(self.command)
    }
}

public struct PeerCommands: Equatable {
    public let commands: [PeerCommand]
    
    public static func ==(lhs: PeerCommands, rhs: PeerCommands) -> Bool {
        return lhs.commands == rhs.commands
    }
}

func _internal_peerCommands(account: Account, id: PeerId) -> Signal<PeerCommands, NoError> {
    return account.postbox.peerView(id: id) |> map { view -> PeerCommands in
        if let cachedUserData = view.cachedData as? CachedUserData {
            if let botInfo = cachedUserData.botInfo {
                if let botPeer = view.peers[id] {
                    var commands: [PeerCommand] = []
                    for command in botInfo.commands {
                        commands.append(PeerCommand(peer: botPeer, command: command))
                    }
                    return PeerCommands(commands: commands)
                }
            }
            return PeerCommands(commands: [])
        } else if let cachedGroupData = view.cachedData as? CachedGroupData {
            var commands: [PeerCommand] = []
            for cachedBotInfo in cachedGroupData.botInfos {
                if let botPeer = view.peers[cachedBotInfo.peerId] {
                    for command in cachedBotInfo.botInfo.commands {
                        commands.append(PeerCommand(peer: botPeer, command: command))
                    }
                }
            }
            return PeerCommands(commands: commands)
        } else if let cachedChannelData = view.cachedData as? CachedChannelData {
            var commands: [PeerCommand] = []
            for cachedBotInfo in cachedChannelData.botInfos {
                if let botPeer = view.peers[cachedBotInfo.peerId] {
                    for command in cachedBotInfo.botInfo.commands {
                        commands.append(PeerCommand(peer: botPeer, command: command))
                    }
                }
            }
            return PeerCommands(commands: commands)
        } else {
            return PeerCommands(commands: [])
        }
    }
    |> distinctUntilChanged
}
