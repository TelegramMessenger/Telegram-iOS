import Foundation
import UIKit
import SwiftSignalKit
import Display
import ImageIO
import TelegramCore
import TinyThumbnail
import FastBlur

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

public enum PeerAvatarImageType {
    case blurred
    case complete
}

public func peerAvatarImageData(account: Account, peerReference: PeerReference?, authorOfMessage: MessageReference?, representation: TelegramMediaImageRepresentation?, synchronousLoad: Bool) -> Signal<(Data, PeerAvatarImageType)?, NoError>? {
    if let smallProfileImage = representation {
        let resourceData = account.postbox.mediaBox.resourceData(smallProfileImage.resource, attemptSynchronously: synchronousLoad)
        let imageData = resourceData
        |> take(1)
        |> mapToSignal { maybeData -> Signal<(Data, PeerAvatarImageType)?, NoError> in
            if maybeData.complete {
                if let data = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path)) {
                    return .single((data, .complete))
                } else {
                    return .single(nil)
                }
            } else {
                return Signal { subscriber in
                    var emittedFirstData = false
                    if let miniData = representation?.immediateThumbnailData, let decodedData = decodeTinyThumbnail(data: miniData) {
                        emittedFirstData = true
                        subscriber.putNext((decodedData, .blurred))
                    }

                    let resourceDataDisposable = resourceData.start(next: { data in
                        if data.complete {
                            if let dataValue = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path)) {
                                subscriber.putNext((dataValue, .complete))
                            } else {
                                subscriber.putNext(nil)
                            }
                            subscriber.putCompletion()
                        } else {
                            if !emittedFirstData {
                                subscriber.putNext(nil)
                            }
                        }
                    }, error: { _ in
                    }, completed: {
                        subscriber.putCompletion()
                    })
                    var fetchedDataDisposable: Disposable?
                    if let peerReference = peerReference {
                        fetchedDataDisposable = fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: .avatar(peer: peerReference, resource: smallProfileImage.resource), statsCategory: .generic).start()
                    } else if let authorOfMessage = authorOfMessage {
                        fetchedDataDisposable = fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: .messageAuthorAvatar(message: authorOfMessage, resource: smallProfileImage.resource), statsCategory: .generic).start()
                    } else {
                        fetchedDataDisposable = fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: .standalone(resource: smallProfileImage.resource), statsCategory: .generic).start()
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

public func peerAvatarCompleteImage(account: Account, peer: EnginePeer, size: CGSize, round: Bool = true, font: UIFont = avatarPlaceholderFont(size: 13.0), drawLetters: Bool = true, fullSize: Bool = false, blurred: Bool = false) -> Signal<UIImage?, NoError> {
    let iconSignal: Signal<UIImage?, NoError>
    if let signal = peerAvatarImage(account: account, peerReference: PeerReference(peer._asPeer()), authorOfMessage: nil, representation: peer.profileImageRepresentations.first, displayDimensions: size, round: round, blurred: blurred, inset: 0.0, emptyColor: nil, synchronousLoad: fullSize) {
        if fullSize, let fullSizeSignal = peerAvatarImage(account: account, peerReference: PeerReference(peer._asPeer()), authorOfMessage: nil, representation: peer.profileImageRepresentations.last, displayDimensions: size, emptyColor: nil, synchronousLoad: true) {
            iconSignal = combineLatest(.single(nil) |> then(signal), .single(nil) |> then(fullSizeSignal))
            |> mapToSignal { thumbnailImage, fullSizeImage -> Signal<UIImage?, NoError> in
                if let fullSizeImage = fullSizeImage {
                    return .single(fullSizeImage.0)
                } else if let thumbnailImage = thumbnailImage {
                    return .single(thumbnailImage.0)
                } else {
                    return .complete()
                }
            }
        } else {
            iconSignal = signal
            |> map { imageVersions -> UIImage? in
                return imageVersions?.0
            }
        }
    } else {
        let peerId = peer.id
        var displayLetters = peer.displayLetters
        if displayLetters.count == 2 && displayLetters[0].isSingleEmoji && displayLetters[1].isSingleEmoji {
            displayLetters = [displayLetters[0]]
        }
        if !drawLetters {
            displayLetters = []
        }
        iconSignal = Signal { subscriber in
            let image = generateImage(size, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                drawPeerAvatarLetters(context: context, size: CGSize(width: size.width, height: size.height), round: round, font: font, letters: displayLetters, peerId: peerId)
                if blurred {
                    context.setFillColor(UIColor(rgb: 0x000000, alpha: 0.5).cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: size))
                }
            })?.withRenderingMode(.alwaysOriginal)
            
            subscriber.putNext(image)
            subscriber.putCompletion()
            return EmptyDisposable
        }
    }
    return iconSignal
}

public func peerAvatarImage(account: Account, peerReference: PeerReference?, authorOfMessage: MessageReference?, representation: TelegramMediaImageRepresentation?, displayDimensions: CGSize = CGSize(width: 60.0, height: 60.0), round: Bool = true, blurred: Bool = false, inset: CGFloat = 0.0, emptyColor: UIColor? = nil, synchronousLoad: Bool = false, provideUnrounded: Bool = false) -> Signal<(UIImage, UIImage)?, NoError>? {
    if let imageData = peerAvatarImageData(account: account, peerReference: peerReference, authorOfMessage: authorOfMessage, representation: representation, synchronousLoad: synchronousLoad) {
        return imageData
        |> mapToSignal { data -> Signal<(UIImage, UIImage)?, NoError> in
            let generate = deferred { () -> Signal<(UIImage, UIImage)?, NoError> in
                if emptyColor == nil && data == nil {
                    return .single(nil)
                }
                let roundedImage = generateImage(displayDimensions, contextGenerator: { size, context -> Void in
                    if let (data, dataType) = data {
                        if let imageSource = CGImageSourceCreateWithData(data as CFData, nil), var dataImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                            context.clear(CGRect(origin: CGPoint(), size: displayDimensions))
                            context.setBlendMode(.copy)
                            
                            if round && displayDimensions.width != 60.0 {
                                context.addEllipse(in: CGRect(origin: CGPoint(), size: displayDimensions).insetBy(dx: inset, dy: inset))
                                context.clip()
                            }

                            var shouldBlur = false
                            if case .blurred = dataType {
                                shouldBlur = true
                            } else if blurred {
                                shouldBlur = true
                            }
                            if shouldBlur {
                                let imageContextSize = size.width > 200.0 ? CGSize(width: 192.0, height: 192.0) : CGSize(width: 64.0, height: 64.0)
                                let imageContext = DrawingContext(size: imageContextSize, scale: 1.0, clear: true)
                                imageContext.withFlippedContext { c in
                                    c.draw(dataImage, in: CGRect(origin: CGPoint(), size: imageContextSize))
                                    
                                    context.setBlendMode(.saturation)
                                    context.setFillColor(UIColor(rgb: 0xffffff, alpha: 1.0).cgColor)
                                    context.fill(CGRect(origin: CGPoint(), size: size))
                                    context.setBlendMode(.copy)
                                }

                                telegramFastBlurMore(Int32(imageContext.size.width * imageContext.scale), Int32(imageContext.size.height * imageContext.scale), Int32(imageContext.bytesPerRow), imageContext.bytes)
                                if size.width > 200.0 {
                                    telegramFastBlurMore(Int32(imageContext.size.width * imageContext.scale), Int32(imageContext.size.height * imageContext.scale), Int32(imageContext.bytesPerRow), imageContext.bytes)
                                    telegramFastBlurMore(Int32(imageContext.size.width * imageContext.scale), Int32(imageContext.size.height * imageContext.scale), Int32(imageContext.bytesPerRow), imageContext.bytes)
                                    telegramFastBlurMore(Int32(imageContext.size.width * imageContext.scale), Int32(imageContext.size.height * imageContext.scale), Int32(imageContext.bytesPerRow), imageContext.bytes)
                                    telegramFastBlurMore(Int32(imageContext.size.width * imageContext.scale), Int32(imageContext.size.height * imageContext.scale), Int32(imageContext.bytesPerRow), imageContext.bytes)
                                }
                                
                                dataImage = imageContext.generateImage()!.cgImage!
                            }
                            
                            context.draw(dataImage, in: CGRect(origin: CGPoint(), size: displayDimensions).insetBy(dx: inset, dy: inset))
                            if blurred {
                                context.setBlendMode(.normal)
                                context.setFillColor(UIColor(rgb: 0x000000, alpha: 0.45).cgColor)
                                context.fill(CGRect(origin: CGPoint(), size: size))
                                context.setBlendMode(.copy)
                            }
                            if round {
                                if displayDimensions.width == 60.0 {
                                    context.setBlendMode(.destinationOut)
                                    context.draw(roundCorners.cgImage!, in: CGRect(origin: CGPoint(), size: displayDimensions).insetBy(dx: inset, dy: inset))
                                }
                            }
                        } else {
                            if let emptyColor = emptyColor {
                                context.clear(CGRect(origin: CGPoint(), size: displayDimensions))
                                context.setFillColor(emptyColor.cgColor)
                                  if round {
                                    context.fillEllipse(in: CGRect(origin: CGPoint(), size: displayDimensions).insetBy(dx: inset, dy: inset))
                                } else {
                                    context.fill(CGRect(origin: CGPoint(), size: displayDimensions).insetBy(dx: inset, dy: inset))
                                }
                            }
                        }
                    } else if let emptyColor = emptyColor {
                        context.clear(CGRect(origin: CGPoint(), size: displayDimensions))
                        context.setFillColor(emptyColor.cgColor)
                        if round {
                            context.fillEllipse(in: CGRect(origin: CGPoint(), size: displayDimensions).insetBy(dx: inset, dy: inset))
                        } else {
                            context.fill(CGRect(origin: CGPoint(), size: displayDimensions).insetBy(dx: inset, dy: inset))
                        }
                    }
                })
                let unroundedImage: UIImage?
                if provideUnrounded {
                    unroundedImage = generateImage(displayDimensions, contextGenerator: { size, context -> Void in
                        if let (data, _) = data {
                            if let imageSource = CGImageSourceCreateWithData(data as CFData, nil), let dataImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                                context.clear(CGRect(origin: CGPoint(), size: displayDimensions))
                                context.setBlendMode(.copy)
                                
                                context.draw(dataImage, in: CGRect(origin: CGPoint(), size: displayDimensions).insetBy(dx: inset, dy: inset))
                            } else {
                                if let emptyColor = emptyColor {
                                    context.clear(CGRect(origin: CGPoint(), size: displayDimensions))
                                    context.setFillColor(emptyColor.cgColor)
                                    context.fill(CGRect(origin: CGPoint(), size: displayDimensions).insetBy(dx: inset, dy: inset))
                                }
                            }
                        } else if let emptyColor = emptyColor {
                            context.clear(CGRect(origin: CGPoint(), size: displayDimensions))
                            context.setFillColor(emptyColor.cgColor)
                            if round {
                                context.fillEllipse(in: CGRect(origin: CGPoint(), size: displayDimensions).insetBy(dx: inset, dy: inset))
                            } else {
                                context.fill(CGRect(origin: CGPoint(), size: displayDimensions).insetBy(dx: inset, dy: inset))
                            }
                        }
                    })
                } else {
                    unroundedImage = roundedImage
                }
                if let roundedImage = roundedImage, let unroundedImage = unroundedImage {
                    return .single((roundedImage, unroundedImage))
                } else {
                    return .single(nil)
                }
            }
            if synchronousLoad {
                return generate
            } else {
                return generate |> runOn(Queue.concurrentDefaultQueue())
            }
        }
    } else {
        return nil
    }
}
