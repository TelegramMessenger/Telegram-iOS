import Foundation
import Postbox
import SwiftSignalKit
import Display
import TelegramCorePrivateModule

private func chatMessageStickerDatas(account: Account, file: TelegramMediaFile) -> Signal<(Data?, Data?, Int), NoError> {
    let fullSizeResource = fileResource(file)
    let maybeFetched = account.postbox.mediaBox.resourceData(fullSizeResource, complete: true)
    
    return maybeFetched |> take(1) |> mapToSignal { maybeData in
        if maybeData.size >= fullSizeResource.size {
            let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
            
            return .single((nil, loadedData, fullSizeResource.size))
        } else {
            let fullSizeData = account.postbox.mediaBox.resourceData(fullSizeResource, complete: true) |> map { next in
                return next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: .mappedIfSafe)
            }
            
            return fullSizeData |> map { data -> (Data?, Data?, Int) in
                return (nil, data, fullSizeResource.size)
            }
        }
    }
}

func chatMessageSticker(account: Account, file: TelegramMediaFile) -> Signal<(TransformImageArguments) -> DrawingContext, NoError> {
    let signal = chatMessageStickerDatas(account: account, file: file)
    
    return signal |> map { (thumbnailData, fullSizeData, fullTotalSize) in
        return { arguments in
            assertNotOnMainThread()
            let context = DrawingContext(size: arguments.drawingSize, clear: true)
            
            var fullSizeImage: UIImage?
            if let fullSizeData = fullSizeData {
                if fullSizeData.count >= fullTotalSize {
                    if let image = UIImage.convert(fromWebP: fullSizeData) {
                        fullSizeImage = image
                    }
                } else {
                }
            }
            
            let thumbnailImage: CGImage? = nil
            
            var blurredThumbnailImage: UIImage?
            if let thumbnailImage = thumbnailImage {
                let thumbnailSize = CGSize(width: thumbnailImage.width, height: thumbnailImage.height)
                let thumbnailContextSize = thumbnailSize.aspectFitted(CGSize(width: 150.0, height: 150.0))
                let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                thumbnailContext.withFlippedContext { c in
                    c.interpolationQuality = .none
                    c.draw(in: CGRect(origin: CGPoint(), size: thumbnailContextSize), image: thumbnailImage)
                }
                telegramFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                
                blurredThumbnailImage = thumbnailContext.generateImage()
            }
            
            context.withFlippedContext { c in
                c.setBlendMode(.copy)
                if let blurredThumbnailImage = blurredThumbnailImage {
                    c.interpolationQuality = .low
                    c.draw(in: arguments.drawingRect, image: blurredThumbnailImage.cgImage!)
                }
                
                if let fullSizeImage = fullSizeImage, let cgImage = fullSizeImage.cgImage {
                    c.setBlendMode(.normal)
                    c.interpolationQuality = .medium
                    c.draw(in: arguments.drawingRect, image: cgImage)
                }
            }
            
            return context
        }
    }
}
