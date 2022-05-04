import Foundation
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import TelegramPresentationData
import UIKit
import WebPBinding
import RLottieBinding
import GZip

public func reactionStaticImage(context: AccountContext, animation: TelegramMediaFile, pixelSize: CGSize) -> Signal<EngineMediaResource.ResourceData, NoError> {
    return context.engine.resources.custom(id: "\(animation.resource.id.stringRepresentation):reaction-static-\(pixelSize.width)x\(pixelSize.height)-v10", fetch: EngineMediaResource.Fetch {
        return Signal { subscriber in
            let fetchDisposable = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: MediaResourceReference.standalone(resource: animation.resource)).start()
            let dataDisposable = context.account.postbox.mediaBox.resourceData(animation.resource).start(next: { data in
                if !data.complete {
                    return
                }
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: data.path)) else {
                    return
                }
                guard let unpackedData = TGGUnzipData(data, 5 * 1024 * 1024) else {
                    return
                }
                guard let instance = LottieInstance(data: unpackedData, fitzModifier: .none, colorReplacements: nil, cacheKey: "") else {
                    return
                }
                
                let renderContext = DrawingContext(size: pixelSize, scale: 1.0, clear: true)

                instance.renderFrame(with: Int32(instance.frameCount - 1), into: renderContext.bytes.assumingMemoryBound(to: UInt8.self), width: Int32(renderContext.size.width * renderContext.scale), height: Int32(renderContext.size.height * renderContext.scale), bytesPerRow: Int32(renderContext.bytesPerRow))
                
                guard let image = renderContext.generateImage() else {
                    return
                }
                guard let pngData = image.pngData() else {
                    return
                }
                
                let tempFile = TempBox.shared.tempFile(fileName: "image.png")
                guard let _ = try? pngData.write(to: URL(fileURLWithPath: tempFile.path)) else {
                    return
                }
                
                subscriber.putNext(.moveTempFile(file: tempFile))
                subscriber.putCompletion()
            })
            
            return ActionDisposable {
                fetchDisposable.dispose()
                dataDisposable.dispose()
            }
        }
    })
}

public final class ReactionImageNode: ASDisplayNode {
    private var disposable: Disposable?
    private let size: CGSize
    private let isAnimation: Bool
    
    private let iconNode: ASImageNode
    
    public init(context: AccountContext, availableReactions: AvailableReactions?, reaction: String, displayPixelSize: CGSize) {
        self.iconNode = ASImageNode()
        
        var file: TelegramMediaFile?
        var animationFile: TelegramMediaFile?
        if let availableReactions = availableReactions {
            for availableReaction in availableReactions.reactions {
                if availableReaction.value == reaction {
                    file = availableReaction.staticIcon
                    animationFile = availableReaction.centerAnimation
                    break
                }
            }
        }
        if let animationFile = animationFile {
            self.size = animationFile.dimensions?.cgSize ?? displayPixelSize
            var displaySize = self.size.aspectFitted(displayPixelSize)
            displaySize.width = floor(displaySize.width * 2.0)
            displaySize.height = floor(displaySize.height * 2.0)
            self.isAnimation = true
            
            super.init()
            
            self.disposable = (reactionStaticImage(context: context, animation: animationFile, pixelSize: CGSize(width: displaySize.width * UIScreenScale, height: displaySize.height * UIScreenScale))
            |> deliverOnMainQueue).start(next: { [weak self] data in
                guard let strongSelf = self else {
                    return
                }
                
                if data.isComplete, let dataValue = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                    if let image = UIImage(data: dataValue) {
                        strongSelf.iconNode.image = image
                    }
                }
            })
        } else if let file = file {
            self.size = file.dimensions?.cgSize ?? displayPixelSize
            self.isAnimation = false
            
            super.init()
            
            self.disposable = (context.account.postbox.mediaBox.resourceData(file.resource)
            |> deliverOnMainQueue).start(next: { [weak self] data in
                guard let strongSelf = self else {
                    return
                }
                
                if data.complete, let dataValue = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                    if let image = WebP.convert(fromWebP: dataValue) {
                        strongSelf.iconNode.image = image
                    }
                }
            })
        } else {
            self.size = displayPixelSize
            self.isAnimation = false
            super.init()
        }
        
        self.addSubnode(self.iconNode)
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    public func update(size: CGSize) {
        var imageSize = self.size.aspectFitted(size)
        if self.isAnimation {
            imageSize.width *= 2.0
            imageSize.height *= 2.0
        }
        self.iconNode.frame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: floor((size.height - imageSize.height) / 2.0)), size: imageSize)
    }
}
