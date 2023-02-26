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
                        fetchedDataDisposable = fetchedMediaResource(mediaBox: account.postbox.mediaBox, userLocation: .other, userContentType: .avatar, reference: .avatar(peer: peerReference, resource: smallProfileImage.resource), statsCategory: .generic).start()
                    } else if let authorOfMessage = authorOfMessage {
                        fetchedDataDisposable = fetchedMediaResource(mediaBox: account.postbox.mediaBox, userLocation: .other, userContentType: .avatar, reference: .messageAuthorAvatar(message: authorOfMessage, resource: smallProfileImage.resource), statsCategory: .generic).start()
                    } else {
                        fetchedDataDisposable = fetchedMediaResource(mediaBox: account.postbox.mediaBox, userLocation: .other, userContentType: .avatar, reference: .standalone(resource: smallProfileImage.resource), statsCategory: .generic).start()
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

public func peerAvatarCompleteImage(account: Account, peer: EnginePeer, forceProvidedRepresentation: Bool = false, representation: TelegramMediaImageRepresentation? = nil, size: CGSize, round: Bool = true, font: UIFont = avatarPlaceholderFont(size: 13.0), drawLetters: Bool = true, fullSize: Bool = false, blurred: Bool = false) -> Signal<UIImage?, NoError> {
    let iconSignal: Signal<UIImage?, NoError>
    
    let clipStyle: AvatarNodeClipStyle
    if round {
        if case let .channel(channel) = peer, channel.flags.contains(.isForum) {
            clipStyle = .roundedRect
        } else {
            clipStyle = .round
        }
    } else {
        clipStyle = .none
    }
    
    let thumbnailRepresentation: TelegramMediaImageRepresentation?
    if forceProvidedRepresentation {
        thumbnailRepresentation = representation
    } else {
        thumbnailRepresentation = peer.profileImageRepresentations.first
    }
    
    if let signal = peerAvatarImage(account: account, peerReference: PeerReference(peer._asPeer()), authorOfMessage: nil, representation: thumbnailRepresentation, displayDimensions: size, clipStyle: clipStyle, blurred: blurred, inset: 0.0, emptyColor: nil, synchronousLoad: fullSize) {
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

public func peerAvatarImage(account: Account, peerReference: PeerReference?, authorOfMessage: MessageReference?, representation: TelegramMediaImageRepresentation?, displayDimensions: CGSize = CGSize(width: 60.0, height: 60.0), clipStyle: AvatarNodeClipStyle = .round, blurred: Bool = false, inset: CGFloat = 0.0, emptyColor: UIColor? = nil, synchronousLoad: Bool = false, provideUnrounded: Bool = false) -> Signal<(UIImage, UIImage)?, NoError>? {
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
                            
                            switch clipStyle {
                            case .none:
                                break
                            case .round:
                                if displayDimensions.width != 60.0 {
                                    context.addEllipse(in: CGRect(origin: CGPoint(), size: displayDimensions).insetBy(dx: inset, dy: inset))
                                    context.clip()
                                }
                            case .roundedRect:
                                context.addPath(UIBezierPath(roundedRect: CGRect(x: 0.0, y: 0.0, width: displayDimensions.width, height: displayDimensions.height).insetBy(dx: inset, dy: inset), cornerRadius: floor(displayDimensions.width * 0.25)).cgPath)
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
                                if let imageContext = DrawingContext(size: imageContextSize, scale: 1.0, clear: true) {
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
                            }
                            
                            context.draw(dataImage, in: CGRect(origin: CGPoint(), size: displayDimensions).insetBy(dx: inset, dy: inset))
                            if blurred {
                                context.setBlendMode(.normal)
                                context.setFillColor(UIColor(rgb: 0x000000, alpha: 0.45).cgColor)
                                context.fill(CGRect(origin: CGPoint(), size: size))
                                context.setBlendMode(.copy)
                            }
                            switch clipStyle {
                            case .none:
                                break
                            case .round:
                                if displayDimensions.width == 60.0 {
                                    context.setBlendMode(.destinationOut)
                                    context.draw(roundCorners.cgImage!, in: CGRect(origin: CGPoint(), size: displayDimensions).insetBy(dx: inset, dy: inset))
                                }
                            case .roundedRect:
                                break
                            }
                        } else {
                            if let emptyColor = emptyColor {
                                context.clear(CGRect(origin: CGPoint(), size: displayDimensions))
                                context.setFillColor(emptyColor.cgColor)
                                switch clipStyle {
                                case .none:
                                    context.fill(CGRect(origin: CGPoint(), size: displayDimensions).insetBy(dx: inset, dy: inset))
                                case .round:
                                    context.fillEllipse(in: CGRect(origin: CGPoint(), size: displayDimensions).insetBy(dx: inset, dy: inset))
                                case .roundedRect:
                                    context.beginPath()
                                    context.addPath(UIBezierPath(roundedRect: CGRect(x: 0.0, y: 0.0, width: displayDimensions.width, height: displayDimensions.height).insetBy(dx: inset, dy: inset), cornerRadius: floor(displayDimensions.width * 0.25)).cgPath)
                                    context.fillPath()
                                }
                            }
                        }
                    } else if let emptyColor = emptyColor {
                        context.clear(CGRect(origin: CGPoint(), size: displayDimensions))
                        context.setFillColor(emptyColor.cgColor)
                        
                        switch clipStyle {
                        case .none:
                            context.fill(CGRect(origin: CGPoint(), size: displayDimensions).insetBy(dx: inset, dy: inset))
                        case .round:
                            context.fillEllipse(in: CGRect(origin: CGPoint(), size: displayDimensions).insetBy(dx: inset, dy: inset))
                        case .roundedRect:
                            context.beginPath()
                            context.addPath(UIBezierPath(roundedRect: CGRect(x: 0.0, y: 0.0, width: displayDimensions.width, height: displayDimensions.height).insetBy(dx: inset, dy: inset), cornerRadius: floor(displayDimensions.width * 0.25)).cgPath)
                            context.fillPath()
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
                            switch clipStyle {
                            case .none:
                                context.fill(CGRect(origin: CGPoint(), size: displayDimensions).insetBy(dx: inset, dy: inset))
                            case .round:
                                context.fillEllipse(in: CGRect(origin: CGPoint(), size: displayDimensions).insetBy(dx: inset, dy: inset))
                            case .roundedRect:
                                context.beginPath()
                                context.addPath(UIBezierPath(roundedRect: CGRect(x: 0.0, y: 0.0, width: displayDimensions.width, height: displayDimensions.height).insetBy(dx: inset, dy: inset), cornerRadius: floor(displayDimensions.width * 0.25)).cgPath)
                                context.fillPath()
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

public func drawPeerAvatarLetters(context: CGContext, size: CGSize, round: Bool = true, font: UIFont, letters: [String], peerId: EnginePeer.Id) {
    if round {
        context.beginPath()
        context.addEllipse(in: CGRect(x: 0.0, y: 0.0, width: size.width, height:
            size.height))
        context.clip()
    }
    
    let colorIndex: Int
    if peerId.namespace == .max {
        colorIndex = -1
    } else {
        colorIndex = Int(clamping: abs(peerId.id._internalGetInt64Value()))
    }
    
    let colorsArray: NSArray
    if colorIndex == -1 {
        colorsArray = AvatarNode.grayscaleColors.map(\.cgColor) as NSArray
    } else {
        colorsArray = AvatarNode.gradientColors[colorIndex % AvatarNode.gradientColors.count].map(\.cgColor) as NSArray
    }
    
    var locations: [CGFloat] = [1.0, 0.0]
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colorsArray, locations: &locations)!
    
    context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
    
    context.resetClip()
    
    context.setBlendMode(.normal)
    
    let string = letters.count == 0 ? "" : (letters[0] + (letters.count == 1 ? "" : letters[1]))
    let attributedString = NSAttributedString(string: string, attributes: [NSAttributedString.Key.font: font, NSAttributedString.Key.foregroundColor: UIColor.white])
    
    let line = CTLineCreateWithAttributedString(attributedString)
    let lineBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    
    let lineOffset = CGPoint(x: string == "B" ? 1.0 : 0.0, y: 0.0)
    let lineOrigin = CGPoint(x: floorToScreenPixels(-lineBounds.origin.x + (size.width - lineBounds.size.width) / 2.0) + lineOffset.x, y: floorToScreenPixels(-lineBounds.origin.y + (size.height - lineBounds.size.height) / 2.0))
    
    context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
    context.scaleBy(x: 1.0, y: -1.0)
    context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
    
    let textPosition = context.textPosition
    context.translateBy(x: lineOrigin.x, y: lineOrigin.y)
    CTLineDraw(line, context)
    context.translateBy(x: -lineOrigin.x, y: -lineOrigin.y)
    context.textPosition = textPosition
}


public enum AvatarBackgroundColor {
    case blue
    case yellow
    case green
    case purple
    case red
    case violet
}

public func generateAvatarImage(size: CGSize, icon: UIImage?, iconScale: CGFloat = 1.0, cornerRadius: CGFloat? = nil, circleCorners: Bool = false, color: AvatarBackgroundColor) -> UIImage? {
    return generateImage(size, rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.beginPath()
        if let cornerRadius {
            if circleCorners {
                let roundedRect = CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
                context.addPath(roundedRect)
            } else {
                let roundedRect = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: cornerRadius)
                context.addPath(roundedRect.cgPath)
            }
        } else {
            context.addEllipse(in: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
        }
        context.clip()
        
        let colorIndex: Int
        switch color {
        case .blue:
            colorIndex = 5
        case .yellow:
            colorIndex = 1
        case .green:
            colorIndex = 3
        case .purple:
            colorIndex = 2
        case .red:
            colorIndex = 0
        case .violet:
            colorIndex = 6
        }
        
        let colorsArray: NSArray
        if colorIndex == -1 {
            colorsArray = AvatarNode.grayscaleColors.map(\.cgColor) as NSArray
        } else {
            colorsArray = AvatarNode.gradientColors[colorIndex % AvatarNode.gradientColors.count].map(\.cgColor) as NSArray
        }
        
        var locations: [CGFloat] = [1.0, 0.0]
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colorsArray, locations: &locations)!
        
        context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        
        context.resetClip()
        
        context.setBlendMode(.normal)
        
        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
        
        if let icon = icon {
            let iconSize = CGSize(width: icon.size.width * iconScale, height: icon.size.height * iconScale)
            let iconFrame = CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) / 2.0), y: floor((size.height - iconSize.height) / 2.0)), size: iconSize)
            context.draw(icon.cgImage!, in: iconFrame)
        }
    })
}
