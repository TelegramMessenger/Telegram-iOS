import Foundation
import UIKit
import TelegramCore
import LegacyComponents
import SwiftSignalKit
import AccountContext

public class VideoConversionWatcher: TGMediaVideoFileWatcher {
    private let update: (String, Int) -> Void
    private var path: String?
    
    public init(update: @escaping (String, Int) -> Void) {
        self.update = update
        
        super.init()
    }
    
    override public func setup(withFileURL fileURL: URL!) {
        self.path = fileURL?.path
        super.setup(withFileURL: fileURL)
    }
    
    override public func fileUpdated(_ completed: Bool) -> Any! {
        if let path = self.path {
            var value = stat()
            if stat(path, &value) == 0 {
                self.update(path, Int(value.st_size))
            }
        }
        
        return super.fileUpdated(completed)
    }
}

public final class LegacyLiveUploadInterfaceResult: NSObject {
    public let id: Int64
    
    init(id: Int64) {
        self.id = id
        
        super.init()
    }
}

public final class LegacyLiveUploadInterface: VideoConversionWatcher, TGLiveUploadInterface {
    private let context: AccountContext
    private let id: Int64
    private var path: String?
    private var size: Int?
    
    private let data = Promise<EngineMediaResource.ResourceData>()
    private let dataValue = Atomic<EngineMediaResource.ResourceData?>(value: nil)
    
    public init(context: AccountContext) {
        self.context = context
        self.id = Int64.random(in: Int64.min ... Int64.max)
        
        var updateImpl: ((String, Int) -> Void)?
        super.init(update: { path, size in
            updateImpl?(path, size)
        })
        
        updateImpl = { [weak self] path, size in
            if let strongSelf = self {
                if strongSelf.path == nil {
                    strongSelf.path = path
                    strongSelf.context.engine.resources.preUpload(id: strongSelf.id, encrypt: false, tag: nil, source: strongSelf.data.get())
                }
                strongSelf.size = size
                
                let result = strongSelf.dataValue.modify { dataValue in
                    if let dataValue = dataValue, dataValue.isComplete {
                        return EngineMediaResource.ResourceData(path: path, availableSize: Int64(size), isComplete: true)
                    } else {
                        return EngineMediaResource.ResourceData(path: path, availableSize: Int64(size), isComplete: false)
                    }
                }
                if let result = result {
                    strongSelf.data.set(.single(result))
                }
            }
        }
    }
    
    deinit {
    }
    
    override public func fileUpdated(_ completed: Bool) -> Any! {
        let _ = super.fileUpdated(completed)
        if completed {
            let result = self.dataValue.modify { dataValue in
                if let dataValue = dataValue {
                    return EngineMediaResource.ResourceData(path: dataValue.path, availableSize: dataValue.availableSize, isComplete: true)
                } else {
                    return nil
                }
            }
            if let result = result {
                self.data.set(.single(result))
                return LegacyLiveUploadInterfaceResult(id: self.id)
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
}
