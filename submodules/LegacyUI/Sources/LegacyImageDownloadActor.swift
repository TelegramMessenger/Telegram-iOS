import Foundation
import UIKit
import LegacyComponents
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit

final class LegacyImageDownloadActor: ASActor {
    private let disposable = MetaDisposable()
    
    deinit {
        self.disposable.dispose()
    }
    
    override static func genericPath() -> String! {
        return "/img/@";
    }
    
    override func execute(_ options: [AnyHashable : Any]!) {
        let actualPath = self.path as NSString
        
        var url: String
        var processor: TGImageProcessor?
        var cacheUrl: String
        if actualPath.hasPrefix("/img/({filter:") {
            let range = actualPath.range(of: "}")
            if range.location == NSNotFound {
                ActionStageInstance().nodeRetrieveFailed(self.path)
                return
            }
            
            let processorName = actualPath.substring(with: NSMakeRange(14, range.location - 14))
            processor = TGRemoteImageView.imageProcessor(forName: processorName)
            url = actualPath.substring(with: NSMakeRange(range.location + 1, actualPath.length - range.location - 1 - 1))
            cacheUrl = "{filter:\(processorName)}\(url)"
        }
        else {
            url = actualPath.substring(with: NSMakeRange(6, actualPath.length - 6 - 1))
            cacheUrl = url
        }
        
        if url.hasPrefix("placeholder://") {
            let path = self.path
            let token = TGImageManager.instance().beginLoadingImageAsync(withUri: url, decode: true, progress: nil, partialCompletion: nil, completion: { image in
                ActionStageInstance().actionCompleted(path, result: SGraphObjectNode(object: image))
            })
            let disposable = ActionDisposable {
                TGImageManager.instance().cancelTask(withId: token)
            }
            self.disposable.set(disposable)
        } else if let resource = resourceFromLegacyImageUri(url) {
            let disposables = DisposableSet()
            self.disposable.set(disposables)
            if let account = legacyContextGet()?.account {
                let path = self.path
                disposables.add(account.postbox.mediaBox.resourceData(resource).start(next: { data in
                    if data.complete {
                        ActionStageInstance().globalStageDispatchQueue().async {
                            if let image = UIImage(contentsOfFile: data.path) {
                                var updatedImage: UIImage? = image
                                if let processor = processor {
                                    updatedImage = processor(image)
                                }
                                TGRemoteImageView.sharedCache().cacheImage(updatedImage, with: nil, url: cacheUrl, availability: Int32(TGCacheMemory.rawValue))
                                ActionStageInstance().actionCompleted(path, result: SGraphObjectNode(object: updatedImage))
                            }
                        }
                    }
                }))
                disposables.add(account.postbox.mediaBox.fetchedResource(resource, parameters: nil).start())
            }
        }
    }
    
    override func cancel() {
        self.disposable.dispose()
    }
}
