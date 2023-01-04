import AccountContext
import Postbox
import SwiftSignalKit
import TelegramCore
import Foundation

public func fetchResource(
    mediaResourceReference: MediaResourceReference,
    userLocation: MediaResourceUserLocation,
    userContentType: MediaResourceUserContentType,
    context: AccountContext) -> Signal<Data?, NoError> {
    let resource = mediaResourceReference.resource
    let mediaBox = context.account.postbox.mediaBox
    
    let resourceData = mediaBox.resourceData(resource)
    return resourceData
    |> take(1)
    |> mapToSignal { maybeData -> Signal<Data?, NoError> in
        if maybeData.complete,
           let data = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path)) {
            return .single(data)
        } else {
            return Signal { subscriber in
                let resourceDataDisposable = resourceData.start(next: { maybeData in
                    if maybeData.complete {
                        if let data = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path)) {
                            subscriber.putNext(data)
                        } else {
                            subscriber.putNext(nil)
                        }
                        subscriber.putCompletion()
                    }
                }, completed: {
                    subscriber.putCompletion()
                })
                let fetchedDataDisposable = fetchedMediaResource(mediaBox: mediaBox, userLocation: userLocation, userContentType: userContentType, reference: mediaResourceReference).start()
                return ActionDisposable {
                    resourceDataDisposable.dispose()
                    fetchedDataDisposable.dispose()
                }
            }
        }
    }
}

public func fetchAvatarImage(peer: Peer, context: AccountContext) -> Signal<Data?, NoError> {
    let photo = peer.profileImageRepresentations
    
    let imageRepresentationWithMaxDimension = photo.max(by: { $0.dimensions.width < $1.dimensions.width })
    
    guard let peerReference = PeerReference(peer) else {
        return .single(nil)
    }
    
    guard let imageRepresentation = imageRepresentationWithMaxDimension else {
        return .single(nil)
    }
    
    return fetchResource(
        mediaResourceReference: .avatar(peer: peerReference, resource: imageRepresentation.resource),
        userLocation: .other,
        userContentType: .avatar,
        context: context)
}
