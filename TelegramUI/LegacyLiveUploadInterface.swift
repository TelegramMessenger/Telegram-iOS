import Foundation
import Postbox
import TelegramCore
import LegacyComponents
import SwiftSignalKit

final class LegacyLiveUploadInterfaceResult: NSObject {
    let id: Int64
    
    init(id: Int64) {
        self.id = id
        
        super.init()
    }
}

final class LegacyLiveUploadInterface: VideoConversionWatcher, TGLiveUploadInterface {
    private let account: Account
    private let id: Int64
    private var path: String?
    private var size: Int?
    
    private let data = Promise<MediaResourceData>()
    private var dataValue: MediaResourceData?
    
    init(account: Account) {
        self.account = account
        self.id = arc4random64()
        
        var updateImpl: ((String, Int) -> Void)?
        super.init(update: { path, size in
            updateImpl?(path, size)
        })
        
        updateImpl = { [weak self] path, size in
            if let strongSelf = self {
                if strongSelf.path == nil {
                    strongSelf.path = path
                    strongSelf.account.messageMediaPreuploadManager.add(network: strongSelf.account.network, postbox: strongSelf.account.postbox, id: strongSelf.id, encrypt: false, tag: TelegramMediaResourceFetchTag(statsCategory: .video), source: strongSelf.data.get())
                }
                strongSelf.size = size
                
                var complete = false
                if let dataValue = strongSelf.dataValue, dataValue.complete {
                    complete = true
                }
                let dataValue = MediaResourceData(path: path, offset: 0, size: size, complete: complete)
                strongSelf.dataValue = dataValue
                strongSelf.data.set(.single(dataValue))
            }
        }
    }
    
    deinit {
    }
    
    override func fileUpdated(_ completed: Bool) -> Any! {
        let _ = super.fileUpdated(completed)
        if completed, let dataValue = self.dataValue {
            self.dataValue = MediaResourceData(path: dataValue.path, offset: dataValue.offset, size: dataValue.size, complete: true)
            self.data.set(.single(dataValue))
            return LegacyLiveUploadInterfaceResult(id: self.id)
        } else {
            return nil
        }
    }
}
