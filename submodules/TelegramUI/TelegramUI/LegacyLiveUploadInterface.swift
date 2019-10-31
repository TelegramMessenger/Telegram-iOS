import Foundation
import UIKit
import Postbox
import TelegramCore
import SyncCore
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
    private let dataValue = Atomic<MediaResourceData?>(value: nil)
    
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
                    strongSelf.account.messageMediaPreuploadManager.add(network: strongSelf.account.network, postbox: strongSelf.account.postbox, id: strongSelf.id, encrypt: false, tag: nil, source: strongSelf.data.get())
                }
                strongSelf.size = size
                
                let result = strongSelf.dataValue.modify { dataValue in
                    if let dataValue = dataValue, dataValue.complete {
                        return MediaResourceData(path: path, offset: 0, size: size, complete: true)
                    } else {
                        return MediaResourceData(path: path, offset: 0, size: size, complete: false)
                    }
                }
                if let result = result {
                    print("**set1 \(result) \(result.complete)")
                    strongSelf.data.set(.single(result))
                }
            }
        }
    }
    
    deinit {
    }
    
    override func fileUpdated(_ completed: Bool) -> Any! {
        let _ = super.fileUpdated(completed)
        if completed {
            let result = self.dataValue.modify { dataValue in
                if let dataValue = dataValue {
                    return MediaResourceData(path: dataValue.path, offset: dataValue.offset, size: dataValue.size, complete: true)
                } else {
                    return nil
                }
            }
            if let result = result {
                print("**set2 \(result) \(completed)")
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
