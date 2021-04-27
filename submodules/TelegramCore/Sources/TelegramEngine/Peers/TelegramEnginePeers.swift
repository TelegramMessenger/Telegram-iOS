import SwiftSignalKit
import Postbox
import SyncCore

public enum AddressNameValidationStatus: Equatable {
    case checking
    case invalidFormat(AddressNameFormatError)
    case availability(AddressNameAvailability)
}

public extension TelegramEngine {
    final class Peers {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func addressNameAvailability(domain: AddressNameDomain, name: String) -> Signal<AddressNameAvailability, NoError> {
            return _internal_addressNameAvailability(account: self.account, domain: domain, name: name)
        }

        public func updateAddressName(domain: AddressNameDomain, name: String?) -> Signal<Void, UpdateAddressNameError> {
            return _internal_updateAddressName(account: self.account, domain: domain, name: name)
        }

        public func checkPublicChannelCreationAvailability(location: Bool = false) -> Signal<Bool, NoError> {
            return _internal_checkPublicChannelCreationAvailability(account: self.account, location: location)
        }

        public func adminedPublicChannels(scope: AdminedPublicChannelsScope = .all) -> Signal<[Peer], NoError> {
            return _internal_adminedPublicChannels(account: self.account, scope: scope)
        }

        public func channelAddressNameAssignmentAvailability(peerId: PeerId?) -> Signal<ChannelAddressNameAssignmentAvailability, NoError> {
            return _internal_channelAddressNameAssignmentAvailability(account: self.account, peerId: peerId)
        }

        public func validateAddressNameInteractive(domain: AddressNameDomain, name: String) -> Signal<AddressNameValidationStatus, NoError> {
            if let error = _internal_checkAddressNameFormat(name) {
                return .single(.invalidFormat(error))
            } else {
                return .single(.checking)
                |> then(
                    self.addressNameAvailability(domain: domain, name: name)
                    |> delay(0.3, queue: Queue.concurrentDefaultQueue())
                    |> map { result -> AddressNameValidationStatus in
                        .availability(result)
                    }
                )
            }
        }

        public func findChannelById(channelId: Int32) -> Signal<Peer?, NoError> {
            return _internal_findChannelById(postbox: self.account.postbox, network: self.account.network, channelId: channelId)
        }

        public func supportPeerId() -> Signal<PeerId?, NoError> {
            return _internal_supportPeerId(account: self.account)
        }

        public func inactiveChannelList() -> Signal<[InactiveChannel], NoError> {
            return _internal_inactiveChannelList(network: self.account.network)
        }

        public func resolvePeerByName(name: String, ageLimit: Int32 = 2 * 60 * 60 * 24) -> Signal<PeerId?, NoError> {
            return _internal_resolvePeerByName(account: self.account, name: name, ageLimit: ageLimit)
        }

        public func searchPeers(query: String) -> Signal<([FoundPeer], [FoundPeer]), NoError> {
            return _internal_searchPeers(account: self.account, query: query)
        }

        public func updatedRemotePeer(peer: PeerReference) -> Signal<Peer, UpdatedRemotePeerError> {
            return _internal_updatedRemotePeer(postbox: self.account.postbox, network: self.account.network, peer: peer)
        }

        public func chatOnlineMembers(peerId: PeerId) -> Signal<Int32, NoError> {
            return _internal_chatOnlineMembers(postbox: self.account.postbox, network: self.account.network, peerId: peerId)
        }

        public func convertGroupToSupergroup(peerId: PeerId) -> Signal<PeerId, ConvertGroupToSupergroupError> {
            return _internal_convertGroupToSupergroup(account: self.account, peerId: peerId)
        }

        public func createGroup(title: String, peerIds: [PeerId]) -> Signal<PeerId?, CreateGroupError> {
            return _internal_createGroup(account: self.account, title: title, peerIds: peerIds)
        }

        public func createSecretChat(peerId: PeerId) -> Signal<PeerId, CreateSecretChatError> {
            return _internal_createSecretChat(account: self.account, peerId: peerId)
        }

        public func setChatMessageAutoremoveTimeoutInteractively(peerId: PeerId, timeout: Int32?) -> Signal<Never, SetChatMessageAutoremoveTimeoutError> {
            return _internal_setChatMessageAutoremoveTimeoutInteractively(account: self.account, peerId: peerId, timeout: timeout)
        }
    }
}
