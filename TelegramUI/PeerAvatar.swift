import Foundation
import SwiftSignalKit
import Postbox
import Display
import ImageIO
import TelegramCore

private let roundCorners = { () -> UIImage in
    let diameter: CGFloat = 60.0
    UIGraphicsBeginImageContextWithOptions(CGSize(width: diameter, height: diameter), false, 0.0)
    let context = UIGraphicsGetCurrentContext()!
    context.setBlendMode(.copy)
    context.setFillColor(UIColor.black.cgColor)
    context.fill(CGRect(origin: CGPoint(), size: CGSize(width: diameter, height: diameter)))
    context.setFillColor(UIColor.clear.cgColor)
    context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: diameter, height: diameter)))
    let image = UIGraphicsGetImageFromCurrentImageContext()!.stretchableImage(withLeftCapWidth: Int(diameter / 2.0), topCapHeight: Int(diameter / 2.0))
    UIGraphicsEndImageContext()
    return image
}()

public func peerAvatarImageData(account: Account, peer: Peer, authorOfMessage: MessageReference?, representation: TelegramMediaImageRepresentation?) -> Signal<Data?, NoError>? {
    if let smallProfileImage = representation {
        let resourceData = account.postbox.mediaBox.resourceData(smallProfileImage.resource)
        let imageData = resourceData
            |> take(1)
            |> mapToSignal { maybeData -> Signal<Data?, NoError> in
                if maybeData.complete {
                    return .single(try? Data(contentsOf: URL(fileURLWithPath: maybeData.path)))
                } else {
                    return Signal { subscriber in
                        let resourceDataDisposable = resourceData.start(next: { data in
                            if data.complete {
                                subscriber.putNext(try? Data(contentsOf: URL(fileURLWithPath: maybeData.path)))
                                subscriber.putCompletion()
                            } else {
                                subscriber.putNext(nil)
                            }
                        }, error: { error in
                            subscriber.putError(error)
                        }, completed: {
                            subscriber.putCompletion()
                        })
                        var fetchedDataDisposable: Disposable?
                        if let peerReference = PeerReference(peer) {
                            fetchedDataDisposable = fetchedMediaResource(postbox: account.postbox, reference: .avatar(peer: peerReference, resource: smallProfileImage.resource), statsCategory: .generic).start()
                        } else if let authorOfMessage = authorOfMessage {
                            fetchedDataDisposable = fetchedMediaResource(postbox: account.postbox, reference: .messageAuthorAvatar(message: authorOfMessage, resource: smallProfileImage.resource), statsCategory: .generic).start()
                        } else {
                            fetchedDataDisposable = fetchedMediaResource(postbox: account.postbox, reference: .standalone(resource: smallProfileImage.resource), statsCategory: .generic).start()
                        }
                        return ActionDisposable {
                            resourceDataDisposable.dispose()
                            fetchedDataDisposable?.dispose()
                        }
                    }
                }
        }
        return imageData
    } else {
        return nil
    }
}

func peerAvatarImage(account: Account, peer: Peer, authorOfMessage: MessageReference?, representation: TelegramMediaImageRepresentation?, displayDimensions: CGSize = CGSize(width: 60.0, height: 60.0)) -> Signal<UIImage?, NoError>? {
    if let imageData = peerAvatarImageData(account: account, peer: peer, authorOfMessage: authorOfMessage, representation: representation) {
        return imageData |> deliverOn(account.graphicsThreadPool)
        |> map { data -> UIImage? in
            if let data = data, let image = generateImage(displayDimensions, contextGenerator: { size, context -> Void in
                if let imageSource = CGImageSourceCreateWithData(data as CFData, nil), let dataImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                    context.setBlendMode(.copy)
                    context.draw(dataImage, in: CGRect(origin: CGPoint(), size: displayDimensions))
                    context.setBlendMode(.destinationOut)
                    context.draw(roundCorners.cgImage!, in: CGRect(origin: CGPoint(), size: displayDimensions))
                }
            }) {
                return image
            } else {
                return nil
            }
        }
    } else {
        return nil
    }
}
