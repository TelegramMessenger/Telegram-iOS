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
                guard let instance = LottieInstance(data: unpackedData, fitzModifier: .none, cacheKey: "") else {
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

public final class ReactionImageNode: ASImageNode {
    private var disposable: Disposable?
    public let size: CGSize
    
    public init(context: AccountContext, availableReactions: AvailableReactions?, reaction: String) {
        var file: TelegramMediaFile?
        if let availableReactions = availableReactions {
            for availableReaction in availableReactions.reactions {
                if availableReaction.value == reaction {
                    file = availableReaction.staticIcon
                    break
                }
            }
        }
        if let file = file {
            self.size = file.dimensions?.cgSize ?? CGSize(width: 18.0, height: 18.0)
            
            super.init()
            
            self.disposable = (context.account.postbox.mediaBox.resourceData(file.resource)
            |> deliverOnMainQueue).start(next: { [weak self] data in
                guard let strongSelf = self else {
                    return
                }
                
                if data.complete, let dataValue = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                    if let image = WebP.convert(fromWebP: dataValue) {
                        strongSelf.image = image
                    }
                }
            })
        } else {
            self.size = CGSize(width: 18.0, height: 18.0)
            super.init()
        }
    }
    
    deinit {
        self.disposable?.dispose()
    }
}

public final class ReactionFileImageNode: ASImageNode {
    private let disposable = MetaDisposable()

    private var currentFile: TelegramMediaFile?
    
    override public init() {
    }
    
    deinit {
        self.disposable.dispose()
    }

    public func asyncLayout() -> (_ context: AccountContext, _ file: TelegramMediaFile?) -> (size: CGSize, apply: () -> Void) {
        return { [weak self] context, file in
            let size = file?.dimensions?.cgSize ?? CGSize(width: 18.0, height: 18.0)
            
            return (size, {
                guard let strongSelf = self else {
                    return
                }
                if strongSelf.currentFile != file {
                    strongSelf.currentFile = file
                    
                    if let file = file {
                        strongSelf.disposable.set((context.account.postbox.mediaBox.resourceData(file.resource)
                        |> deliverOnMainQueue).start(next: { data in
                            guard let strongSelf = self else {
                                return
                            }
                            
                            if data.complete, let dataValue = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                                if let image = WebP.convert(fromWebP: dataValue) {
                                    strongSelf.image = image
                                }
                            }
                        }))
                    }
                }
            })
        }
    }
}
