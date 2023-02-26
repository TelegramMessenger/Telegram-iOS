import Foundation
import LottieComponent
import SwiftSignalKit
import TelegramCore
import AccountContext
import GZip

public extension LottieComponent {
    final class EmojiContent: LottieComponent.Content {
        private let context: AccountContext
        private let fileId: Int64

        public init(
            context: AccountContext,
            fileId: Int64
        ) {
            self.context = context
            self.fileId = fileId
            
            super.init()
        }

        override public func isEqual(to other: Content) -> Bool {
            guard let other = other as? EmojiContent else {
                return false
            }
            if self.fileId != other.fileId {
                return false
            }
            return true
        }
        
        override public func load(_ f: @escaping (Data, String?) -> Void) -> Disposable {
            let fileId = self.fileId
            let mediaBox = self.context.account.postbox.mediaBox
            return (self.context.engine.stickers.resolveInlineStickers(fileIds: [fileId])
            |> mapToSignal { files -> Signal<Data?, NoError> in
                guard let file = files[fileId] else {
                    return .single(nil)
                }
                return Signal { subscriber in
                    let dataDisposable = (mediaBox.resourceData(file.resource)
                    |> filter { data in return data.complete }).start(next: { data in
                        if let contents = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                            let result = TGGUnzipData(contents, 2 * 1024 * 1024) ?? contents
                            subscriber.putNext(result)
                            subscriber.putCompletion()
                        } else {
                            subscriber.putNext(nil)
                        }
                    })
                    let fetchDisposable = mediaBox.fetchedResource(file.resource, parameters: nil).start()
                    
                    return ActionDisposable {
                        dataDisposable.dispose()
                        fetchDisposable.dispose()
                    }
                }
            }).start(next: { data in
                guard let data else {
                    return
                }
                f(data, nil)
            })
        }
    }
}
