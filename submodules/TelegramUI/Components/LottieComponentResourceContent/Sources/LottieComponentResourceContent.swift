import Foundation
import LottieComponent
import SwiftSignalKit
import TelegramCore
import AccountContext
import GZip

public extension LottieComponent {
    final class ResourceContent: LottieComponent.Content {
        private let context: AccountContext
        private let file: TelegramMediaFile
        private let attemptSynchronously: Bool
        
        override public var frameRange: Range<Double> {
            return 0.0 ..< 1.0
        }

        public init(
            context: AccountContext,
            file: TelegramMediaFile,
            attemptSynchronously: Bool
        ) {
            self.context = context
            self.file = file
            self.attemptSynchronously = attemptSynchronously
            
            super.init()
        }

        override public func isEqual(to other: Content) -> Bool {
            guard let other = other as? ResourceContent else {
                return false
            }
            if self.file.fileId != other.file.fileId {
                return false
            }
            if self.attemptSynchronously != other.attemptSynchronously {
                return false
            }
            return true
        }
        
        override public func load(_ f: @escaping (Data, String?) -> Void) -> Disposable {
            let attemptSynchronously = self.attemptSynchronously
            let file = self.file
            let mediaBox = self.context.account.postbox.mediaBox
            return Signal<Data?, NoError> { subscriber in
                if attemptSynchronously {
                    if let path = mediaBox.completedResourcePath(file.resource), let contents = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                        let result = TGGUnzipData(contents, 2 * 1024 * 1024) ?? contents
                        subscriber.putNext(result)
                        subscriber.putCompletion()
                        
                        return EmptyDisposable
                    }
                }
                
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
            }.start(next: { data in
                guard let data else {
                    return
                }
                f(data, nil)
            })
        }
    }
}
